package com.fatwabot.feature.hadith

import androidx.lifecycle.ViewModel
import com.fatwabot.core.common.ActivityEventRecording
import com.fatwabot.core.common.HapticsProviding
import com.fatwabot.core.common.NoopActivityEventRecording
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
    private val haptics: HapticsProviding,
    private val activityEvents: ActivityEventRecording = NoopActivityEventRecording(),
) : ViewModel() {

    data class UiState(
        val collections: List<HadithCollectionSummary> = emptyList(),
        val hasLoadedCollections: Boolean = false,
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
        _state.update {
            it.copy(
                collections = contentService?.hadithCollections(locale).orEmpty(),
                hasLoadedCollections = true,
            )
        }
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

    /**
     * Records an entry as read because it scrolled into view. Mirror of iOS
     * `HadithViewModel.markRead(number:)`.
     *
     * ## Why this exists alongside [markCurrentRead]
     * Progress used to advance only through [next]/[previous], because the reader
     * showed one entry at a time. The collection is now a scrollable list, so
     * there is no "current" entry to advance to — "read" has to mean "reached the
     * screen", which is what a list can actually observe.
     *
     * This does mean a fast scroll marks several entries at once. That is a real
     * change in what progress measures, and it is the honest reading of a list:
     * the alternative — a dwell timer, or a "mark read" control on every card —
     * either lies in the other direction or puts a chore on a reading surface.
     *
     * Idempotent: the streak event fires only the first time an entry is seen, so
     * scrolling back up does not re-award anything.
     *
     * No haptic, unlike [markCurrentRead]. There, one tick acknowledged one
     * deliberate tap on "next"; here the trigger is scrolling, and a tick per card
     * arriving on screen would buzz for the length of a flick.
     */
    fun markRead(number: Int) {
        val current = _state.value
        val detail = current.currentDetail ?: return
        val existing = current.progress[detail.slug] ?: HadithProgress()
        if (number in existing.readNumbers) return
        val updated = existing.copy(
            readNumbers = existing.readNumbers + number,
            lastReadNumber = number,
        )
        val newProgress = current.progress + (detail.slug to updated)
        store.saveProgress(newProgress)
        _state.update { it.copy(progress = newProgress) }
        activityEvents.record(eventType = "hadith_entry_read")
    }

    private fun markCurrentRead() {
        val current = _state.value
        val detail = current.currentDetail ?: return
        val entry = current.currentEntry ?: return
        val existing = current.progress[detail.slug] ?: HadithProgress()
        val isNewlyRead = entry.number !in existing.readNumbers
        val updated = existing.copy(readNumbers = existing.readNumbers + entry.number, lastReadNumber = entry.number)
        val newProgress = current.progress + (detail.slug to updated)
        store.saveProgress(newProgress)
        _state.update { it.copy(progress = newProgress) }
        if (isNewlyRead) {
            activityEvents.record(eventType = "hadith_entry_read")
            haptics.tick()
        }
    }
}
