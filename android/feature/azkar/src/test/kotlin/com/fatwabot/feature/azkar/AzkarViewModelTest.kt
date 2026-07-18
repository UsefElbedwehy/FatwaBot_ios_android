package com.fatwabot.feature.azkar

import com.fatwabot.core.common.ActivityEventRecording
import com.fatwabot.core.common.NoopHaptics
import com.fatwabot.core.content.AzkarItem
import kotlinx.datetime.Clock
import kotlinx.datetime.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** Mirrors iOS AzkarViewModelTests — both must behave identically. */
class AzkarViewModelTest {
    private class InMemoryStore : AzkarStoring {
        var session: AzkarSessionState? = null
        var completions: MutableList<AzkarCompletionRecord> = mutableListOf()
        override fun loadSession(): AzkarSessionState? = session
        override fun saveSession(session: AzkarSessionState?) {
            this.session = session
        }
        override fun loadCompletions(): List<AzkarCompletionRecord> = completions
        override fun recordCompletion(record: AzkarCompletionRecord) {
            completions.add(record)
        }
    }

    private class SpyActivityEvents : ActivityEventRecording {
        val recorded = mutableListOf<String>()
        override fun record(eventType: String, metadata: Map<String, String>) { recorded += eventType }
    }

    private fun item(id: String, repeatCount: Int) = AzkarItem(
        id = id, sortOrder = 0, arabicText = "ذكر $id", transliteration = null,
        translation = null, virtueNote = null, source = "", repeatCount = repeatCount,
    )

    private val fixedNow = Instant.fromEpochSeconds(1_774_000_000)
    private val fixedClock = object : Clock {
        override fun now() = fixedNow
    }

    @Test
    fun `auto-advance at exactly repeatCount reaches next item, not overshooting`() {
        val items = listOf(item("a", 3), item("b", 1))
        val viewModel = AzkarViewModel(null, NoopHaptics(), InMemoryStore(), fixedClock)
        viewModel.startSession("cat1", items)

        viewModel.tick() // 1
        viewModel.tick() // 2
        assertEquals(0, viewModel.state.value.currentItemIndex)
        assertEquals(2, viewModel.state.value.currentItemCount)

        viewModel.tick() // 3 -> reaches repeatCount exactly -> advances
        assertEquals(1, viewModel.state.value.currentItemIndex)
        assertEquals(0, viewModel.state.value.currentItemCount)
    }

    @Test
    fun `resume mid-session same day restores exact position`() {
        val store = InMemoryStore()
        val items = listOf(item("a", 5), item("b", 5))
        val first = AzkarViewModel(null, NoopHaptics(), store, fixedClock)
        first.startSession("cat1", items)
        first.tick()
        first.tick() // count = 2, still on item 0

        val second = AzkarViewModel(null, NoopHaptics(), store, fixedClock)
        second.startSession("cat1", items)

        assertEquals(0, second.state.value.currentItemIndex)
        assertEquals(2, second.state.value.currentItemCount)
    }

    @Test
    fun `resume does not apply across different category or day`() {
        val store = InMemoryStore()
        val items = listOf(item("a", 5))
        val first = AzkarViewModel(null, NoopHaptics(), store, fixedClock)
        first.startSession("cat1", items)
        first.tick()

        val second = AzkarViewModel(null, NoopHaptics(), store, fixedClock)
        second.startSession("cat2", items)
        assertEquals(0, second.state.value.currentItemCount)

        val nextDayClock = object : Clock {
            override fun now() = Instant.fromEpochSeconds(fixedNow.epochSeconds + 86_400 * 2)
        }
        val third = AzkarViewModel(null, NoopHaptics(), store, nextDayClock)
        third.startSession("cat1", items)
        assertEquals(0, third.state.value.currentItemCount)
    }

    @Test
    fun `session completion is idempotent`() {
        val store = InMemoryStore()
        val items = listOf(item("a", 1))
        val viewModel = AzkarViewModel(null, NoopHaptics(), store, fixedClock)
        viewModel.startSession("cat1", items)

        viewModel.tick() // completes the only item -> session complete
        assertTrue(viewModel.state.value.isSessionComplete)
        assertEquals(1, store.completions.size)

        viewModel.tick()
        viewModel.tick()
        assertEquals(1, store.completions.size)
        assertTrue(viewModel.isCompletedToday("cat1"))
    }

    @Test
    fun `real completion fires an activity event exactly once, not on the idempotent re-tick`() {
        val events = SpyActivityEvents()
        val items = listOf(item("a", 1))
        val viewModel = AzkarViewModel(null, NoopHaptics(), InMemoryStore(), fixedClock, events)
        viewModel.startSession("cat1", items)

        viewModel.tick()
        viewModel.tick()
        viewModel.tick()

        assertEquals(listOf("azkar_completed"), events.recorded)
    }

    @Test
    fun `completed today loads from existing history on init`() {
        val store = InMemoryStore()
        store.completions = mutableListOf(AzkarCompletionRecord("cat1", fixedNow.epochSeconds))
        val viewModel = AzkarViewModel(null, NoopHaptics(), store, fixedClock)
        assertTrue(viewModel.isCompletedToday("cat1"))
        assertEquals(false, viewModel.isCompletedToday("cat2"))
    }

    @Test
    fun `progress reflects item index over total`() {
        val items = listOf(item("a", 1), item("b", 1), item("c", 1))
        val viewModel = AzkarViewModel(null, NoopHaptics(), InMemoryStore(), fixedClock)
        viewModel.startSession("cat1", items)
        assertEquals(0.0, viewModel.state.value.progress, 0.001)
        viewModel.tick()
        assertEquals(1.0 / 3.0, viewModel.state.value.progress, 0.001)
    }
}
