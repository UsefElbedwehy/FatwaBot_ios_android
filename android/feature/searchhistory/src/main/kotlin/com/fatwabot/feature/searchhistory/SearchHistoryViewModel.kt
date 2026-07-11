package com.fatwabot.feature.searchhistory

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

/** State machine for the Search History screen (docs/features/search-history.md). */
@HiltViewModel
class SearchHistoryViewModel @Inject constructor(
    private val client: AuthenticatedApiClientProtocol,
    private val haptics: HapticsProviding,
) : ViewModel() {
    private val json = Json { ignoreUnknownKeys = true }

    data class UiState(
        val entries: List<SearchHistoryEntry> = emptyList(),
        val isLoading: Boolean = false,
        val error: String? = null,
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    suspend fun load() {
        _state.update { it.copy(isLoading = true, error = null) }
        runCatching {
            val raw = client.getRaw("v1/search-history")
            json.decodeFromString(ListSearchHistoryResponse.serializer(), raw).entries
        }.fold(
            onSuccess = { entries -> _state.update { it.copy(entries = entries, isLoading = false) } },
            onFailure = { error -> _state.update { it.copy(error = error.toString(), isLoading = false) } },
        )
    }

    suspend fun delete(entry: SearchHistoryEntry) {
        val previous = _state.value.entries
        _state.update { it.copy(entries = it.entries.filterNot { e -> e.id == entry.id }) }
        haptics.tick()
        runCatching {
            client.deleteRaw("v1/search-history/${entry.id}")
        }.onFailure { error ->
            _state.update { it.copy(entries = previous, error = error.toString()) }
        }
    }

    /** Caller must confirm first — this is destructive. */
    suspend fun clearAll() {
        val previous = _state.value.entries
        _state.update { it.copy(entries = emptyList()) }
        haptics.tick()
        runCatching {
            client.deleteRaw("v1/search-history")
        }.onFailure { error ->
            _state.update { it.copy(entries = previous, error = error.toString()) }
        }
    }
}
