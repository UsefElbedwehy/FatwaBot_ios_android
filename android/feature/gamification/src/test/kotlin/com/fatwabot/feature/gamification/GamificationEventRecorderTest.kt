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
