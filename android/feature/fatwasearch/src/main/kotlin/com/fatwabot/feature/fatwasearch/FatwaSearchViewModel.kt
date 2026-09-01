package com.fatwabot.feature.fatwasearch

import com.fatwabot.core.network.ApiException
import com.fatwabot.core.network.AuthenticatedApiClientProtocol
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.serialization.json.Json

/** Kill switch for the whole AI-search flow, independent of what the backend
 * would actually return. Search is fully built and already degrades to the
 * "coming soon" framing on its own when the provider keys aren't configured
 * (503 `ai_unavailable`) — this flag existed for the separate, non-technical
 * reason that the OCR corpus's copyright/licensing basis isn't resolved yet.
 *
 * Enabled for testing now that both provider keys are configured. This is
 * still safe with an unresolved corpus: retrieval enforces
 * `license_status = 'granted'` in SQL (`0042_fatwa_schema.sql`), and nothing
 * ingested pre-pause has ever been flipped to `'granted'` — so search will
 * refuse ("couldn't find a vetted source") rather than surface any
 * copyrighted content, regardless of this flag. */
object FatwaSearchFeatureFlags {
    const val SEARCH_ENABLED = true
}

/** State machine for the AI fatwa-search flow (`POST /v1/search`,
 * docs/features/ai-search-m5.0-spec.md §App wiring) — mirror of iOS
 * FatwaSearchViewModel.
 *
 * A plain class rather than a `@HiltViewModel`: `mode`/`initialQuestion` are
 * fixed per ask (like every other per-instance construction in this app —
 * see `AwradCreateSheet`), not something Hilt's zero-arg ViewModel factories
 * are set up to carry. The screen `remember`s one per (mode, initialQuestion)
 * and resolves [AuthenticatedApiClientProtocol] via a Hilt entry point,
 * mirroring `WorshipTab.kt`'s `ConfigServiceEntryPoint` pattern. */
class FatwaSearchViewModel(
    private val client: AuthenticatedApiClientProtocol,
    val mode: FatwaSearchMode,
    initialQuestion: String,
    private val searchEnabled: Boolean = FatwaSearchFeatureFlags.SEARCH_ENABLED,
) {
    sealed interface Phase {
        data object Idle : Phase
        data object Loading : Phase

        /** 503 `ai_unavailable` — the AI stack isn't configured yet. Distinct
         * from [Error] so the UI can show the same "coming soon" framing the
         * Home cards already use, rather than an alarming failure state for
         * something that is expected right now. */
        data object Unavailable : Phase
        data class Error(val message: String) : Phase
        data class Result(val response: SearchResponse) : Phase
    }

    data class UiState(val question: String, val phase: Phase = Phase.Idle)

    private val json = Json { ignoreUnknownKeys = true }
    private val _state = MutableStateFlow(UiState(question = initialQuestion))
    val state: StateFlow<UiState> = _state.asStateFlow()

    fun updateQuestion(text: String) {
        _state.update { it.copy(question = text) }
    }

    suspend fun submit() {
        val trimmed = _state.value.question.trim()
        if (trimmed.isEmpty()) return
        if (!searchEnabled) {
            _state.update { it.copy(phase = Phase.Unavailable) }
            return
        }
        _state.update { it.copy(phase = Phase.Loading) }
        runCatching {
            val body = json.encodeToString(SearchRequestBody.serializer(), SearchRequestBody(trimmed, mode.wireValue))
            val raw = client.postRaw("v1/search", body)
            json.decodeFromString(SearchResponse.serializer(), raw)
        }.fold(
            onSuccess = { response -> _state.update { it.copy(phase = Phase.Result(response)) } },
            onFailure = { error ->
                val phase = if (error is ApiException.Server && error.statusCode == 503 && error.code == "ai_unavailable") {
                    Phase.Unavailable
                } else {
                    Phase.Error(error.toString())
                }
                _state.update { it.copy(phase = phase) }
            },
        )
    }

    /** Back to a blank ask — used by "ask again" after a result or refusal. */
    fun reset() {
        _state.update { UiState(question = "") }
    }
}
