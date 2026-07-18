package com.fatwabot.feature.tasbeeh

import com.fatwabot.core.common.ActivityEventRecording
import com.fatwabot.core.common.HapticsProviding
import com.fatwabot.core.common.NoopHaptics
import kotlinx.datetime.Clock
import kotlinx.datetime.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** Mirrors iOS TasbeehViewModelTests — both must behave identically. */
class TasbeehViewModelTest {

    private class SpyHaptics : HapticsProviding {
        var tickCount = 0
        var targetReachedCount = 0
        override fun tick() { tickCount++ }
        override fun targetReached() { targetReachedCount++ }
    }

    private class SpyActivityEvents : ActivityEventRecording {
        val recorded = mutableListOf<String>()
        override fun record(eventType: String, metadata: Map<String, String>) { recorded += eventType }
    }

    private class InMemoryStore : TasbeehHistoryStoring {
        var entries: List<TasbeehHistoryEntry> = emptyList()
        override fun load() = entries
        override fun save(history: List<TasbeehHistoryEntry>) { entries = history }
    }

    private val fixedClock = object : Clock {
        override fun now() = Instant.fromEpochSeconds(1_774_000_000)
    }

    @Test
    fun `increment past target does not reset or block`() {
        val viewModel = TasbeehViewModel(NoopHaptics(), InMemoryStore(), fixedClock)
        viewModel.changeTarget(3)
        repeat(10) { viewModel.increment() }
        assertEquals(10, viewModel.state.value.count)
    }

    @Test
    fun `distinct haptic fires exactly once at target crossing`() {
        val haptics = SpyHaptics()
        val viewModel = TasbeehViewModel(haptics, InMemoryStore(), fixedClock)
        viewModel.changeTarget(3)
        repeat(5) { viewModel.increment() }
        assertEquals(1, haptics.targetReachedCount)
        assertEquals(4, haptics.tickCount)
    }

    @Test
    fun `reset zeroes count without touching history`() {
        val viewModel = TasbeehViewModel(NoopHaptics(), InMemoryStore(), fixedClock)
        viewModel.changeTarget(3)
        viewModel.increment()
        viewModel.increment()
        viewModel.reset()
        assertEquals(0, viewModel.state.value.count)
        assertTrue(viewModel.state.value.history.isEmpty())
    }

    @Test
    fun `history total is sum of actual counts not targets`() {
        val store = InMemoryStore()
        val viewModel = TasbeehViewModel(NoopHaptics(), store, fixedClock)
        viewModel.changeTarget(3)
        repeat(5) { viewModel.increment() }
        viewModel.completeSet()
        viewModel.changeTarget(3)
        repeat(3) { viewModel.increment() }
        viewModel.completeSet()

        assertEquals(2, viewModel.state.value.stats.setsCompleted)
        assertEquals(8, viewModel.state.value.stats.totalCount)
        assertEquals(2, store.entries.size)
    }

    @Test
    fun `complete set with zero count is a no-op`() {
        val store = InMemoryStore()
        val viewModel = TasbeehViewModel(NoopHaptics(), store, fixedClock)
        viewModel.completeSet()
        assertTrue(store.entries.isEmpty())
    }

    @Test
    fun `completing a set fires an activity event`() {
        val events = SpyActivityEvents()
        val viewModel = TasbeehViewModel(NoopHaptics(), InMemoryStore(), fixedClock, events)
        viewModel.increment()
        viewModel.completeSet()
        assertEquals(listOf("tasbeeh_session_completed"), events.recorded)
    }

    @Test
    fun `completing an empty set does not fire an activity event`() {
        val events = SpyActivityEvents()
        val viewModel = TasbeehViewModel(NoopHaptics(), InMemoryStore(), fixedClock, events)
        viewModel.completeSet()
        assertTrue(events.recorded.isEmpty())
    }

    @Test
    fun `custom dhikr text is not saved as a preset`() {
        val viewModel = TasbeehViewModel(NoopHaptics(), InMemoryStore(), fixedClock)
        viewModel.select(DhikrPreset.CUSTOM)
        viewModel.updateCustomText("دعاء خاص")
        assertEquals("دعاء خاص", viewModel.state.value.displayText)
        assertFalse(DhikrPreset.bundled.any { it.arabicText == "دعاء خاص" })
    }

    @Test
    fun `selecting preset resets in-progress count`() {
        val viewModel = TasbeehViewModel(NoopHaptics(), InMemoryStore(), fixedClock)
        viewModel.increment()
        viewModel.increment()
        viewModel.select(DhikrPreset.bundled[1])
        assertEquals(0, viewModel.state.value.count)
    }

    @Test
    fun `history loads from store on init`() {
        val store = InMemoryStore()
        store.entries = listOf(
            TasbeehHistoryEntry("1", "subhanallah", null, 33, 33, 0),
        )
        val viewModel = TasbeehViewModel(NoopHaptics(), store, fixedClock)
        assertEquals(1, viewModel.state.value.history.size)
        assertEquals(33, viewModel.state.value.stats.totalCount)
    }
}
