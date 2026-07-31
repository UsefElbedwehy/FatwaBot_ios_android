package com.fatwabot.feature.leaderboard

import androidx.lifecycle.ViewModel
import com.fatwabot.core.common.HapticsProviding
import com.fatwabot.core.network.AuthenticatedApiClientProtocol
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.serialization.json.Json

/** State machine for the Leaderboards screen (docs/features/leaderboard.md).
 * A single generic renderer drives every board — no per-scope/per-period
 * client code; unknown scope/period values just render generically. */
@HiltViewModel
class LeaderboardViewModel @Inject constructor(
    private val client: AuthenticatedApiClientProtocol,
    private val haptics: HapticsProviding,
    private val region: RegionResolving,
) : ViewModel() {
    private val json = Json { ignoreUnknownKeys = true }

    data class UiState(
        val boards: List<LeaderboardBoard> = emptyList(),
        val isLoading: Boolean = false,
        val error: String? = null,
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    suspend fun load() {
        _state.update { it.copy(isLoading = true, error = null) }
        runCatching {
            val raw = client.getRaw("v1/leaderboards")
            json.decodeFromString(ListBoardsResponse.serializer(), raw).boards
        }.fold(
            onSuccess = { boards -> _state.update { it.copy(boards = boards, isLoading = false) } },
            onFailure = { error -> _state.update { it.copy(error = error.toString(), isLoading = false) } },
        )
    }

    /** Optimistically flips `joined` locally so the UI reacts immediately;
     * the subsequent `load()` reconciles with the server's authoritative state. */
    /**
     * @param city an explicit choice from the UI. When null, a regional board
     *   derives one from the prayer-times location rather than failing — the
     *   user has already told the app where they are.
     */
    suspend fun join(key: String, publishName: Boolean, city: String? = null) {
        val scope = _state.value.boards.firstOrNull { it.key == key }?.scope ?: "global"
        val isRegional = scope == "city" || scope == "country"
        // Only resolve for a board that needs it: a global join must not trigger
        // a location read the user gets nothing from.
        val resolved = if (isRegional) region.currentRegion() else LeaderboardRegion.Unknown
        runCatching {
            val body = json.encodeToString(
                JoinLeaderboardRequest.serializer(),
                JoinLeaderboardRequest(
                    publishName = publishName,
                    city = if (scope == "city") city ?: resolved.city else null,
                    country = if (scope == "country") resolved.countryCode else null,
                ),
            )
            client.postRaw("v1/leaderboards/$key/join", body)
        }.fold(
            onSuccess = { haptics.targetReached(); load() },
            onFailure = { error -> _state.update { it.copy(error = error.toString()) } },
        )
    }

    suspend fun leave(key: String) {
        runCatching {
            client.postEmptyRaw("v1/leaderboards/$key/leave")
        }.fold(
            onSuccess = { load() },
            onFailure = { error -> _state.update { it.copy(error = error.toString()) } },
        )
    }
}
