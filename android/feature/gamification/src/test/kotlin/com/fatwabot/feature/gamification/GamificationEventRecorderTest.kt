package com.fatwabot.feature.gamification

import com.fatwabot.core.network.AuthenticatedApiClientProtocol
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

private class InMemoryQueueStore : ActivityEventQueueStoring {
    private var events: List<QueuedActivityEvent> = emptyList()
    override fun load(): List<QueuedActivityEvent> = events
    override fun save(events: List<QueuedActivityEvent>) {
        this.events = events
    }
}

private class FakeEventsApiClient(
    private val onPost: (String, String) -> String = { _, _ -> """{"accepted":1,"duplicates":0}""" },
) : AuthenticatedApiClientProtocol {
    var postCalls = 0
        private set

    override suspend fun getRaw(path: String, query: Map<String, String>) = ""
    override suspend fun postRaw(path: String, jsonBody: String): String {
        postCalls++
        return onPost(path, jsonBody)
    }
    override suspend fun postEmptyRaw(path: String) = ""
    override suspend fun patchRaw(path: String, jsonBody: String) = ""
    override suspend fun deleteRaw(path: String) = ""
}

class GamificationEventRecorderTest {

    // MARK: - Drain (mirrors iOS WorshipInboxDrainTests)

    private fun tempInbox(): com.fatwabot.core.common.WorshipInbox =
        com.fatwabot.core.common.WorshipInbox(
            java.io.File(
                java.nio.file.Files.createTempDirectory("inbox").toFile(),
                "worship-inbox",
            ),
        )

    private fun inboxEntry(prayer: String = "fajr") = com.fatwabot.core.common.WorshipInboxEntry(
        eventType = "prayer_completed",
        occurredAtEpochSeconds = java.time.Instant.now().epochSecond,
        metadata = mapOf("prayer" to prayer),
    )

    @Test
    fun drainPreservesTheIdMintedAtTheTap() = runTest {
        var body = ""
        val client = FakeEventsApiClient { _, json ->
            body = json
            """{"accepted":1,"duplicates":0}"""
        }
        val recorder = GamificationEventRecorder(InMemoryQueueStore(), client)
        val inbox = tempInbox()
        val entry = inboxEntry()
        inbox.deposit(entry)

        recorder.drain(inbox)

        // Asserted against the submitted payload, not the queue: a successful
        // flush empties the queue, so queue state proves nothing here.
        //
        // The id is the entire idempotency story. Re-minting it would mean a
        // drain that runs twice counts the same prayer twice.
        assertTrue(body.contains(entry.clientEventId))
        assertTrue(inbox.peek().isEmpty())
    }

    @Test
    fun aFailedUploadKeepsTheDeedRatherThanLosingIt() = runTest {
        val store = InMemoryQueueStore()
        val client = FakeEventsApiClient { _, _ -> throw RuntimeException("offline") }
        val recorder = GamificationEventRecorder(store, client)
        val inbox = tempInbox()
        val entry = inboxEntry("asr")
        inbox.deposit(entry)

        recorder.drain(inbox)

        // Adopted by the event queue, which is itself retried. What must never
        // happen is the deed vanishing from both.
        assertEquals(listOf(entry.clientEventId), store.load().map { it.clientEventId })
    }

    @Test
    fun drainingTwiceDoesNotEnqueueTheSameDeedTwice() = runTest {
        val store = InMemoryQueueStore()
        val client = FakeEventsApiClient { _, _ -> throw RuntimeException("offline") }
        val recorder = GamificationEventRecorder(store, client)
        val inbox = tempInbox()
        val entry = inboxEntry("isha")

        inbox.deposit(entry)
        recorder.drain(inbox)
        // The crash window: adopted into the queue, still present in the inbox
        // because clearing never completed.
        inbox.deposit(entry)
        recorder.drain(inbox)

        assertEquals(1, store.load().size)
    }

    @Test
    fun drainOnAnEmptyInboxDoesNotCallTheNetwork() = runTest {
        val client = FakeEventsApiClient()
        GamificationEventRecorder(InMemoryQueueStore(), client).drain(tempInbox())
        // Every foreground calls this. It must be free when there is nothing to do.
        assertEquals(0, client.postCalls)
    }

    @Test
    fun recordQueuesLocallyEvenBeforeFlushCompletes() {
        val store = InMemoryQueueStore()
        val client = FakeEventsApiClient()
        val dispatcher = StandardTestDispatcher()
        val scope = TestScope(dispatcher)
        val recorder = GamificationEventRecorder(store, client, scope)

        recorder.record("azkar_completed", mapOf("category" to "morning"))

        assertEquals(1, store.load().size)
        assertEquals("azkar_completed", store.load().first().eventType)
    }

    @Test
    fun flushSubmitsAndClearsQueueOnSuccess() = runTest {
        val store = InMemoryQueueStore()
        store.save(listOf(QueuedActivityEvent(eventType = "tasbeeh_session_completed", occurredAtEpochSeconds = 100, timezone = "UTC")))
        val client = FakeEventsApiClient()
        val recorder = GamificationEventRecorder(store, client, this)

        recorder.flush()

        assertEquals(1, client.postCalls)
        assertTrue(store.load().isEmpty())
    }

    @Test
    fun flushKeepsQueueOnFailure() = runTest {
        val store = InMemoryQueueStore()
        store.save(listOf(QueuedActivityEvent(eventType = "wird_ticked", occurredAtEpochSeconds = 100, timezone = "UTC")))
        val client = FakeEventsApiClient(onPost = { _, _ -> throw RuntimeException("network down") })
        val recorder = GamificationEventRecorder(store, client, this)

        recorder.flush()

        assertEquals(1, store.load().size)
    }

    @OptIn(ExperimentalCoroutinesApi::class)
    @Test
    fun recordEventuallyFlushesViaScope() = runTest {
        val store = InMemoryQueueStore()
        val client = FakeEventsApiClient()
        val recorder = GamificationEventRecorder(store, client, this)

        recorder.record("hadith_entry_read")
        advanceUntilIdle()

        assertEquals(1, client.postCalls)
        assertTrue(store.load().isEmpty())
    }
}
