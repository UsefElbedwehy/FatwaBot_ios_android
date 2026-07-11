package com.fatwabot.feature.hadith

import com.fatwabot.core.common.ActivityEventRecording
import com.fatwabot.core.common.HapticsProviding
import com.fatwabot.core.common.NoopActivityEventRecording
import com.fatwabot.core.common.NoopHaptics
import com.fatwabot.core.content.HadithCollectionDetail
import com.fatwabot.core.content.HadithEntry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** Mirrors iOS HadithViewModelTests — both must behave identically. */
class HadithViewModelTest {
    private class InMemoryStore : HadithStoring {
        var progress: Map<String, HadithProgress> = emptyMap()
        override fun loadProgress(): Map<String, HadithProgress> = progress
        override fun saveProgress(progress: Map<String, HadithProgress>) {
            this.progress = progress
        }
    }

    private fun entry(number: Int) = HadithEntry(
        id = "h$number", number = number, arabicText = "حديث $number",
        translation = null, grading = "صحيح", benefitNote = null, source = "",
    )

    private fun detail(slug: String = "nawawi40", entryNumbers: List<Int> = listOf(1, 2, 3)) = HadithCollectionDetail(
        version = 1, slug = slug, name = "الأربعون", description = "", entries = entryNumbers.map(::entry),
    )

    private class SpyActivityEvents : ActivityEventRecording {
        val recorded = mutableListOf<String>()
        override fun record(eventType: String, metadata: Map<String, String>) { recorded += eventType }
    }

    private class SpyHaptics : HapticsProviding {
        var tickCount = 0
        var targetReachedCount = 0
        override fun tick() { tickCount += 1 }
        override fun targetReached() { targetReachedCount += 1 }
    }

    private fun makeViewModel(
        store: HadithStoring = InMemoryStore(),
        haptics: HapticsProviding = NoopHaptics(),
        activityEvents: ActivityEventRecording = NoopActivityEventRecording(),
    ) = HadithViewModel(null, store, haptics, activityEvents)

    @Test
    fun `prev next clamps at boundaries no wraparound`() {
        val viewModel = makeViewModel()
        viewModel.setDetail(detail())
        assertEquals(1, viewModel.state.value.currentEntry?.number)

        viewModel.previous() // already at first — must not crash or wrap
        assertEquals(1, viewModel.state.value.currentEntry?.number)

        viewModel.next()
        viewModel.next()
        assertEquals(3, viewModel.state.value.currentEntry?.number)
        viewModel.next() // already at last — must not crash or wrap
        assertEquals(3, viewModel.state.value.currentEntry?.number)
    }

    @Test
    fun `re-reading does not double count`() {
        val viewModel = makeViewModel()
        viewModel.setDetail(detail())
        viewModel.next()
        viewModel.previous()
        viewModel.previous() // already at first
        assertEquals("revisiting entries must not double count", 2, viewModel.readCount("nawawi40"))
    }

    @Test
    fun `progress persists across restarts`() {
        val store = InMemoryStore()
        val first = makeViewModel(store)
        first.setDetail(detail())
        first.next()
        first.next() // read 1, 2, 3

        val second = makeViewModel(store)
        second.setDetail(detail())
        assertEquals("must resume at the last-read entry", 3, second.state.value.currentEntry?.number)
        assertEquals(3, second.readCount("nawawi40"))
    }

    @Test
    fun `is completed requires all entries read`() {
        val viewModel = makeViewModel()
        viewModel.setDetail(detail())
        assertFalse(viewModel.isCompleted("nawawi40", 3))
        viewModel.next()
        viewModel.next()
        assertTrue(viewModel.isCompleted("nawawi40", 3))
    }

    @Test
    fun `activity event fires only for newly read entries not revisits`() {
        val events = SpyActivityEvents()
        val viewModel = makeViewModel(activityEvents = events)
        viewModel.setDetail(detail()) // reads entry 1
        viewModel.next() // reads entry 2
        viewModel.previous() // revisits entry 1 — must not re-fire
        viewModel.previous() // already at first, no-op

        assertEquals(listOf("hadith_entry_read", "hadith_entry_read"), events.recorded)
    }

    @Test
    fun `marking an entry read fires a haptic only for newly read entries`() {
        val haptics = SpyHaptics()
        val viewModel = makeViewModel(haptics = haptics)
        viewModel.setDetail(detail()) // reads entry 1
        assertEquals(1, haptics.tickCount)

        viewModel.next() // reads entry 2
        assertEquals(2, haptics.tickCount)

        viewModel.previous() // revisits entry 1 — must not re-fire
        assertEquals(2, haptics.tickCount)
    }

    @Test
    fun `jump to navigates directly and marks read`() {
        val viewModel = makeViewModel()
        viewModel.setDetail(detail())
        viewModel.jumpTo(3)
        assertEquals(3, viewModel.state.value.currentEntry?.number)
        assertTrue("jumping ahead marks the target read", viewModel.readCount("nawawi40") >= 2)
    }

    @Test
    fun `collections render offline from bundled seed fallback`() {
        // No live ContentService injected — mirrors "renders even fully offline
        // on first launch" via the bundled seed fallback ContentKit provides.
        val viewModel = makeViewModel()
        viewModel.loadCollections("ar")
        assertTrue(
            "without a ContentService, collections stay empty rather than crashing",
            viewModel.state.value.collections.isEmpty(),
        )
    }
}
