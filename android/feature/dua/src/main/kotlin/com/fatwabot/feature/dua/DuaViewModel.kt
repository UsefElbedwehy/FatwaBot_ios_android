package com.fatwabot.feature.dua

import androidx.lifecycle.ViewModel
import com.fatwabot.core.common.HapticsProviding
import com.fatwabot.core.common.NoopSearchHistoryRecording
import com.fatwabot.core.common.SearchHistoryRecording
import com.fatwabot.core.content.ContentService
import com.fatwabot.core.content.Dua
import com.fatwabot.core.content.DuaCategory
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.datetime.Clock

/**
 * Library browse/search/favorite state — mirror of iOS DuaViewModel
 * (docs/features/dua.md). Category loading from ContentKit is a thin
 * synchronous wrapper; search/favorite logic is unit-testable with
 * hand-built fixtures via [setCategories].
 */
@HiltViewModel
class DuaViewModel @Inject constructor(
    private val contentService: ContentService?,
    private val store: DuaStoring,
    private val clock: Clock,
    private val haptics: HapticsProviding,
    private val searchHistory: SearchHistoryRecording = NoopSearchHistoryRecording(),
) : ViewModel() {
    private var locale = "ar"
    /** Dedupes recording on repeated identical queries (e.g. focus loss
     * re-triggering) — not a full debounce, but the spec explicitly allows either. */
    private var lastRecordedQuery: String? = null

    data class UiState(
        val categories: List<DuaCategory> = emptyList(),
        val hasLoadedCategories: Boolean = false,
        val searchQuery: String = "",
        /** duaId -> addedAt epoch seconds. Dictionary (not array-index) so
         * favorites survive content resync — the spec's "keyed by stable
         * duaId" requirement. */
        val favorites: Map<String, Long> = emptyMap(),
    ) {
        val allDuas: List<Dua>
            get() = categories.flatMap { it.duas }

        /** Most-recently-favorited first. */
        val favoriteDuas: List<Dua>
            get() = allDuas.filter { favorites.containsKey(it.id) }
                .sortedByDescending { favorites[it.id] }

        fun isFavorite(duaId: String): Boolean = favorites.containsKey(duaId)

        /** `null` means "not searching" (empty query); an empty list means
         * "searched, no matches" — screens must distinguish these. */
        val searchResults: List<Dua>?
            get() {
                val normalized = DuaSearch.normalize(searchQuery)
                if (normalized.isEmpty()) return null
                return allDuas.filter { dua ->
                    DuaSearch.normalize(dua.title).contains(normalized) ||
                        DuaSearch.normalize(dua.arabicText).contains(normalized) ||
                        (dua.translation?.let { DuaSearch.normalize(it).contains(normalized) } ?: false)
                }
            }
    }

    private val _state = MutableStateFlow(
        UiState(
            favorites = store.loadFavorites().associate { it.duaId to it.addedAtEpochSeconds },
        ),
    )
    val state: StateFlow<UiState> = _state.asStateFlow()

    fun loadCategories(locale: String) {
        this.locale = locale
        setCategories(contentService?.duas(locale)?.categories.orEmpty())
        _state.update { it.copy(hasLoadedCategories = true) }
    }

    /** Internal seam so search/favorite logic is testable without a live
     * ContentService (mirrors AzkarViewModel.startSession taking items directly). */
    fun setCategories(categories: List<DuaCategory>) {
        _state.update { it.copy(categories = categories) }
    }

    fun updateSearchQuery(query: String) {
        _state.update { it.copy(searchQuery = query) }
        val results = _state.value.searchResults
        if (results != null && results.isNotEmpty() && query != lastRecordedQuery) {
            lastRecordedQuery = query
            searchHistory.record(source = "dua", queryText = query, locale = locale)
        }
    }

    fun toggleFavorite(duaId: String) {
        val current = _state.value.favorites
        val updated = if (current.containsKey(duaId)) {
            haptics.tick()
            current - duaId
        } else {
            haptics.targetReached()
            current + (duaId to clock.now().epochSeconds)
        }
        store.saveFavorites(updated.map { FavoriteDua(it.key, it.value) })
        _state.update { it.copy(favorites = updated) }
    }
}
