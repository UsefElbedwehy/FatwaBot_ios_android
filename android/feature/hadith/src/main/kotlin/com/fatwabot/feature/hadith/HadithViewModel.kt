package com.fatwabot.feature.hadith

import androidx.lifecycle.ViewModel
import com.fatwabot.core.content.ContentService
import com.fatwabot.core.content.HadithCollectionDetail
import com.fatwabot.core.content.HadithCollectionSummary
import com.fatwabot.core.content.HadithEntry
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

/**
 * Collections browser + reading state — mirror of iOS HadithViewModel
 * (docs/features/hadith-collections.md). Entries auto-mark as read on
 * navigation; content loading from ContentKit is a thin synchronous wrapper
 * kept separate so navigation/progress logic is unit-testable.
 */
@HiltViewModel
class HadithViewModel @Inject constructor(
    private val contentService: ContentService?,
    private val store: HadithStoring,
) : ViewModel() {

    data class UiState(
        val collections: List<HadithCollectionSummary> = emptyList(),
        val currentDetail: HadithCollectionDetail? = null,
        val currentIndex: Int = 0,
        val progress: Map<String, HadithProgress> = emptyMap(),
    ) {
        val currentEntry: HadithEntry?
            get() = currentDetail?.entries?.getOrNull(currentIndex)

        fun readCount(slug: String): Int = progress[slug]?.readNumbers?.size ?: 0

        fun isCompleted(slug: String, totalEntries: Int): Boolean =
            totalEntries > 0 && readCount(slug) >= totalEntries
    }

    private val _state = MutableStateFlow(UiState(progress = store.loadProgress()))
    val state: StateFlow<UiState> = _state.asStateFlow()

    fun loadCollections(locale: String) {
        _state.update { it.copy(collections = contentService?.hadithCollections(locale).orEmpty()) }
    }

    /** Opens a collection, resuming at the last-read entry if one exists. */
    fun openCollection(slug: String, locale: String) {
        val detail = contentService?.hadithDetail(slug, locale) ?: return
        setDetail(detail)
    }

    /** Test-only seam so navigation logic is testable without a live
     * ContentService (mirrors AzkarViewModel.startSession taking items directly). */
    fun setDetail(detail: HadithCollectionDetail) {
        val lastRead = _state.value.progress[detail.slug]?.lastReadNumber
        val index = lastRead?.let { number -> detail.entries.indexOfFirst { it.number == number } }
            ?.takeIf { it >= 0 } ?: 0
        _state.update { it.copy(currentDetail = detail, currentIndex = index) }
        markCurrentRead()
    }

    fun readCount(forSlug: String): Int = _state.value.readCount(forSlug)

    fun isCompleted(slug: String, totalEntries: Int): Boolean = _state.value.isCompleted(slug, totalEntries)

    /** Clamps at the last entry — no wraparound, no crash. */
    fun next() {
        val current = _state.value
        val detail = current.currentDetail ?: return
        if (current.currentIndex >= detail.entries.size - 1) return
        _state.update { it.copy(currentIndex = it.currentIndex + 1) }
        markCurrentRead()
    }

    /** Clamps at the first entry — no wraparound, no crash. */
    fun previous() {
        if (_state.value.currentIndex <= 0) return
        _state.update { it.copy(currentIndex = it.currentIndex - 1) }
        markCurrentRead()
    }

    fun jumpTo(number: Int) {
        val detail = _state.value.currentDetail ?: return
        val index = detail.entries.indexOfFirst { it.number == number }
        if (index < 0) return
        _state.update { it.copy(currentIndex = index) }
        markCurrentRead()
    }

    private fun markCurrentRead() {
        val current = _state.value
        val detail = current.currentDetail ?: return
        val entry = current.currentEntry ?: return
        val existing = current.progress[detail.slug] ?: HadithProgress()
        val updated = existing.copy(readNumbers = existing.readNumbers + entry.number, lastReadNumber = entry.number)
        val newProgress = current.progress + (detail.slug to updated)
        store.saveProgress(newProgress)
        _state.update { it.copy(progress = newProgress) }
    }
}
