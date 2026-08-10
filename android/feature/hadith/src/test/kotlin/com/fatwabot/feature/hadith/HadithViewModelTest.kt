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

    // MARK: - markRead (the list-shaped reader)

    /*
     * The collection screen is a scroll list now, so progress advances from cards
     * appearing rather than from prev/next. These mirror the iOS cases exactly.
     */

    @Test
    fun `scrolling an entry into view marks it read and records one event`() {
        val events = SpyActivityEvents()
        val viewModel = makeViewModel(activityEvents = events)
        viewModel.setDetail(detail())

        viewModel.markRead(2)

        assertEquals(2, viewModel.readCount("nawawi40"))
        assertEquals(listOf("hadith_entry_read", "hadith_entry_read"), events.recorded)
    }

    /**
     * Scrolling back up re-triggers the per-card effect for entries already seen.
     * If that re-awarded the streak, a user could farm it by flicking.
     */
    @Test
    fun `scrolling back over a seen entry awards nothing`() {
        val events = SpyActivityEvents()
        val viewModel = makeViewModel(activityEvents = events)
        viewModel.setDetail(detail())

        viewModel.markRead(2)
        val afterFirstPass = events.recorded.size

        viewModel.markRead(2)
        viewModel.markRead(2)
        viewModel.markRead(1)

        assertEquals(afterFirstPass, events.recorded.size)
        assertEquals(2, viewModel.readCount("nawawi40"))
    }

    /**
     * A haptic per card arriving on screen would buzz for the length of a flick.
     * `markCurrentRead` still ticks; this path deliberately does not.
     */
    @Test
    fun `scrolling does not fire haptics`() {
        val haptics = SpyHaptics()
        val viewModel = makeViewModel(haptics = haptics)
        viewModel.setDetail(detail())
        val afterOpen = haptics.tickCount

        viewModel.markRead(2)
        viewModel.markRead(3)

        assertEquals(afterOpen, haptics.tickCount)
    }

    @Test
    fun `scrolling through every entry completes the collection`() {
        val viewModel = makeViewModel()
        viewModel.setDetail(detail())
        assertFalse(viewModel.isCompleted("nawawi40", 3))

        viewModel.markRead(2)
        viewModel.markRead(3)

        assertTrue(viewModel.isCompleted("nawawi40", 3))
    }

    /**
     * The per-card effect can fire while a chip change is still loading the next
     * collection, so this is reachable in practice, not just in theory.
     */
    @Test
    fun `mark read before a collection loads is a no-op`() {
        val events = SpyActivityEvents()
        val viewModel = makeViewModel(activityEvents = events)

        viewModel.markRead(1)

        assertEquals(0, viewModel.readCount("nawawi40"))
        assertTrue(events.recorded.isEmpty())
    }

    @Test
    fun `scrolled progress persists across restarts`() {
        val store = InMemoryStore()
        val first = HadithViewModel(null, store, NoopHaptics(), NoopActivityEventRecording())
        first.setDetail(detail())
        first.markRead(2)
        first.markRead(3)

        val second = HadithViewModel(null, store, NoopHaptics(), NoopActivityEventRecording())
        second.setDetail(detail())
        assertEquals(3, second.readCount("nawawi40"))
    }
}
