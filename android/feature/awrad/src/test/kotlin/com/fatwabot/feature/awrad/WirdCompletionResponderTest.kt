package com.fatwabot.feature.awrad

import com.fatwabot.core.common.ActivityEventRecording
import com.fatwabot.core.common.NoopHaptics
import java.time.ZoneId
import kotlinx.datetime.Clock
import kotlinx.datetime.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The notification answer writes the same state the UI writes, from a process
 * where no view model exists. These tests are the guard on that equivalence —
 * the failure mode they exist to prevent (a day reported complete whose per-wird
 * counts don't support it) is silent and permanently inflates the Journey stats.
 */
class WirdCompletionResponderTest {

    private class InMemoryStore : WirdStoring {
        var wirds: List<Wird> = emptyList()
        var progress: List<WirdDailyProgress> = emptyList()
        var completions: List<WirdDayCompletionRecord> = emptyList()
        override fun loadWirds() = wirds
        override fun saveWirds(wirds: List<Wird>) { this.wirds = wirds }
        override fun loadProgress() = progress
        override fun saveProgress(progress: List<WirdDailyProgress>) { this.progress = progress }
        override fun loadDayCompletions() = completions
        override fun recordDayCompletion(record: WirdDayCompletionRecord) { completions = completions + record }
    }

    private class SpyEvents : ActivityEventRecording {
        val recorded = mutableListOf<Pair<String, Map<String, String>>>()
        override fun record(eventType: String, metadata: Map<String, String>) {
            recorded += eventType to metadata
        }
        val types: List<String> get() = recorded.map { it.first }
    }

    private val fixedNow = Instant.fromEpochSeconds(1_774_000_000)
    private val fixedClock = object : Clock { override fun now() = fixedNow }
    private val utc: ZoneId = ZoneId.of("UTC")
    private val todayKey = AwradViewModel.dateKey(fixedNow.epochSeconds, utc)

    private fun wird(id: String, target: Int, archived: Boolean = false) = Wird(
        id = id,
        name = "ورد",
        type = "dhikr",
        target = target,
        unit = "times",
        frequency = "daily",
        createdAtEpochSeconds = 1_770_000_000,
        archivedAtEpochSeconds = if (archived) 1_773_000_000 else null,
    )

    private fun responder(store: WirdStoring, events: ActivityEventRecording = SpyEvents()) =
        WirdCompletionResponder(store, events, fixedClock, utc)

    // region Bringing the wird to target

    @Test
    fun `answer raises count to exactly the target`() {
        val store = InMemoryStore().apply { wirds = listOf(wird("a", 33)) }

        val outcome = responder(store).answerCompleted("a")

        assertTrue(outcome.ticked)
        assertEquals(1, store.progress.size)
        assertEquals(33, store.progress[0].count)
        assertEquals(todayKey, store.progress[0].dateKey)
    }

    @Test
    fun `answer tops up a partially done wird rather than adding a target`() {
        val store = InMemoryStore().apply {
            wirds = listOf(wird("a", 100))
            progress = listOf(WirdDailyProgress("a", todayKey, 40))
        }

        responder(store).answerCompleted("a")

        assertEquals(100, store.progress[0].count)
    }

    @Test
    fun `answer leaves an earlier day's progress alone`() {
        val store = InMemoryStore().apply {
            wirds = listOf(wird("a", 10))
            progress = listOf(WirdDailyProgress("a", "2000-01-01", 7))
        }

        responder(store).answerCompleted("a")

        assertEquals(2, store.progress.size)
        assertEquals(7, store.progress.first { it.dateKey == "2000-01-01" }.count)
        assertEquals(10, store.progress.first { it.dateKey == todayKey }.count)
    }

    // endregion

    // region Idempotency

    @Test
    fun `repeated answers do not double count or double record`() {
        val store = InMemoryStore().apply { wirds = listOf(wird("a", 33)) }
        val events = SpyEvents()
        val responder = responder(store, events)

        val first = responder.answerCompleted("a")
        val second = responder.answerCompleted("a")
        val third = responder.answerCompleted("a")

        assertTrue(first.ticked)
        assertFalse(second.ticked)
        assertFalse(third.ticked)
        assertEquals(33, store.progress[0].count)
        assertEquals(1, events.types.count { it == "wird_ticked" })
        assertEquals(1, store.completions.size)
        assertTrue(first.dayCompleted)
        assertFalse(second.dayCompleted)
    }

    @Test
    fun `answering a wird already past its target is a no-op`() {
        val store = InMemoryStore().apply {
            wirds = listOf(wird("a", 10))
            progress = listOf(WirdDailyProgress("a", todayKey, 25))
        }
        val events = SpyEvents()

        val outcome = responder(store, events).answerCompleted("a")

        assertFalse(outcome.ticked)
        assertEquals(25, store.progress[0].count)
        assertFalse(events.types.contains("wird_ticked"))
    }

    // endregion

    // region Day completion honesty

    @Test
    fun `answering the last outstanding wird records day completion`() {
        val store = InMemoryStore().apply {
            wirds = listOf(wird("a", 3), wird("b", 5))
            progress = listOf(WirdDailyProgress("a", todayKey, 3))
        }
        val events = SpyEvents()

        val outcome = responder(store, events).answerCompleted("b")

        assertTrue(outcome.dayCompleted)
        assertEquals(listOf(todayKey), store.completions.map { it.dateKey })
        assertEquals(listOf("wird_ticked", "wird_day_completed"), events.types)
    }

    @Test
    fun `answering one of several does not record day completion`() {
        val store = InMemoryStore().apply { wirds = listOf(wird("a", 3), wird("b", 5)) }
        val events = SpyEvents()

        val outcome = responder(store, events).answerCompleted("a")

        assertTrue(outcome.ticked)
        assertFalse(outcome.dayCompleted)
        assertTrue(store.completions.isEmpty())
        assertEquals(listOf("wird_ticked"), events.types)
    }

    @Test
    fun `archived wirds do not block day completion`() {
        val store = InMemoryStore().apply {
            wirds = listOf(wird("a", 3), wird("old", 500, archived = true))
        }

        assertTrue(responder(store).answerCompleted("a").dayCompleted)
    }

    @Test
    fun `day completion is not recorded twice when already present`() {
        val store = InMemoryStore().apply {
            wirds = listOf(wird("a", 3))
            completions = listOf(WirdDayCompletionRecord(todayKey, fixedNow.epochSeconds))
        }
        val events = SpyEvents()

        val outcome = responder(store, events).answerCompleted("a")

        assertTrue(outcome.ticked)
        assertFalse(outcome.dayCompleted)
        assertEquals(1, store.completions.size)
        assertEquals(listOf("wird_ticked"), events.types)
    }

    // endregion

    // region Stale ids

    @Test
    fun `unknown wird id is a no-op`() {
        val store = InMemoryStore().apply { wirds = listOf(wird("a", 3)) }
        val events = SpyEvents()

        val outcome = responder(store, events).answerCompleted("deleted")

        assertEquals(WirdCompletionOutcome.UNKNOWN_WIRD, outcome)
        assertTrue(store.progress.isEmpty())
        assertTrue(store.completions.isEmpty())
        assertTrue(events.recorded.isEmpty())
    }

    @Test
    fun `archived wird id is a no-op`() {
        val store = InMemoryStore().apply { wirds = listOf(wird("old", 3, archived = true)) }
        val events = SpyEvents()

        val outcome = responder(store, events).answerCompleted("old")

        assertEquals(WirdCompletionOutcome.UNKNOWN_WIRD, outcome)
        assertTrue(store.progress.isEmpty())
        assertTrue(events.recorded.isEmpty())
    }

    @Test
    fun `an empty store is a no-op rather than a crash`() {
        assertEquals(
            WirdCompletionOutcome.UNKNOWN_WIRD,
            responder(InMemoryStore()).answerCompleted("anything"),
        )
    }

    // endregion

    /**
     * The whole point: whichever route the user takes, gamification sees the same
     * events and the store lands in the same shape.
     */
    @Test
    fun `store and events match the in-app path`() {
        val notificationStore = InMemoryStore().apply { wirds = listOf(wird("a", 7)) }
        val notificationEvents = SpyEvents()
        val uiStore = InMemoryStore().apply { wirds = listOf(wird("a", 7)) }
        val uiEvents = SpyEvents()

        // System zone rather than UTC here: the view model's `todayKey()` always
        // uses the default zone, and the two paths must agree on the SAME day.
        WirdCompletionResponder(notificationStore, notificationEvents, fixedClock, ZoneId.systemDefault())
            .answerCompleted("a")

        val viewModel = AwradViewModel(
            contentService = null,
            store = uiStore,
            clock = fixedClock,
            haptics = NoopHaptics(),
            activityEvents = uiEvents,
        )
        viewModel.tick("a", amount = 7)
        viewModel.markDayComplete()

        assertEquals(uiStore.progress, notificationStore.progress)
        assertEquals(
            uiStore.completions.map { it.dateKey },
            notificationStore.completions.map { it.dateKey },
        )
        assertEquals(uiEvents.types, notificationEvents.types)
        assertEquals(uiEvents.recorded.first().second, notificationEvents.recorded.first().second)
    }

}
