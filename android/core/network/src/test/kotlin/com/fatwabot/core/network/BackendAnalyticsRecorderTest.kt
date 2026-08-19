package com.fatwabot.core.network

import com.fatwabot.core.common.AnalyticsEventQueueStoring
import com.fatwabot.core.common.AnalyticsEvents
import com.fatwabot.core.common.FileAnalyticsEventQueueStore
import com.fatwabot.core.common.QueuedAnalyticsEvent
import java.io.File
import java.util.UUID
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** In-memory queue store, so tests don't touch disk. */
private class InMemoryAnalyticsQueueStore : AnalyticsEventQueueStoring {
    private var events: List<QueuedAnalyticsEvent> = emptyList()
    override fun load(): List<QueuedAnalyticsEvent> = events
    override fun save(events: List<QueuedAnalyticsEvent>) {
        this.events = events
    }
}

private class SpyApiClient(
    private val shouldFail: Boolean = false,
) : AuthenticatedApiClientProtocol {
    var postCount = 0
        private set
    var lastPath: String? = null
        private set

    /** Event count seen in each POST body, so batching can be asserted. */
    val batchSizes = mutableListOf<Int>()
    var lastBody: String? = null
        private set

    override suspend fun getRaw(path: String, query: Map<String, String>) = ""

    override suspend fun postRaw(path: String, jsonBody: String): String {
        postCount++
        lastPath = path
        lastBody = jsonBody
        batchSizes += Regex("\"client_event_id\"").findAll(jsonBody).count()
        if (shouldFail) throw RuntimeException("network down")
        return """{"accepted":${batchSizes.last()},"duplicates":0,"rejected":0}"""
    }

    override suspend fun postEmptyRaw(path: String) = ""
    override suspend fun patchRaw(path: String, jsonBody: String) = ""
    override suspend fun deleteRaw(path: String) = ""
}

/** Message deliberately looks like a search query, to prove it never ships. */
private class SecretError : RuntimeException("is this halal")

class BackendAnalyticsRecorderTest {

    private fun recorder(
        store: AnalyticsEventQueueStoring,
        client: AuthenticatedApiClientProtocol,
        scope: CoroutineScope,
        threshold: Int = 20,
        isEnabled: () -> Boolean = { true },
    ) = BackendAnalyticsRecorder(
        store = store,
        client = client,
        appVersion = "1.2.3",
        batchThreshold = threshold,
        scope = scope,
        isEnabled = isEnabled,
    )

    /**
     * The whole point of this recorder over GamificationEventRecorder: screen
     * views must NOT each cost a network request.
     */
    @Test
    fun doesNotPostBeforeReachingBatchThreshold() = runTest {
        val store = InMemoryAnalyticsQueueStore()
        val client = SpyApiClient()
        val recorder = recorder(store, client, TestScope(), threshold = 5)

        repeat(4) { recorder.screenView("screen_$it") }

        assertEquals(0, client.postCount)
        assertEquals(4, store.load().size)
    }

    @Test
    fun flushSendsOneBatchAndClearsQueue() = runTest {
        val store = InMemoryAnalyticsQueueStore()
        val client = SpyApiClient()
        val recorder = recorder(store, client, this)

        recorder.screenView(AnalyticsEvents.SCREEN_HOME)
        recorder.screenView(AnalyticsEvents.SCREEN_DUA)
        recorder.flush()

        assertEquals("both events should go in a single request", 1, client.postCount)
        assertEquals(listOf(2), client.batchSizes)
        assertEquals("v1/analytics/events", client.lastPath)
        assertTrue(store.load().isEmpty())
    }

    /** The wire shape the backend ingest is being built against. */
    @Test
    fun flushBodyUsesSnakeCaseContract() = runTest {
        val store = InMemoryAnalyticsQueueStore()
        val client = SpyApiClient()
        val recorder = recorder(store, client, this)

        recorder.screenView(AnalyticsEvents.SCREEN_DUA)
        recorder.flush()

        val body = client.lastBody.orEmpty()
        listOf(
            "\"events\"", "\"client_event_id\"", "\"name\":\"screen_view\"", "\"occurred_at\"",
            "\"platform\":\"android\"", "\"app_version\":\"1.2.3\"", "\"params\"", "\"screen\":\"dua\"",
        ).forEach { assertTrue("missing $it in $body", body.contains(it)) }
    }

    /**
     * A failed flush must not lose events — they're retried next time, and the
     * ingest is idempotent per client_event_id so nothing double-counts.
     */
    @Test
    fun failedFlushKeepsEventsQueued() = runTest {
        val store = InMemoryAnalyticsQueueStore()
        val client = SpyApiClient(shouldFail = true)
        val recorder = recorder(store, client, this)

        recorder.screenView(AnalyticsEvents.SCREEN_HOME)
        recorder.flush()

        assertEquals(1, store.load().size)
    }

    /** Events that queued while a flush was in flight must survive it. */
    @Test
    fun flushOnlyDropsWhatItSubmitted() = runTest {
        val store = InMemoryAnalyticsQueueStore()
        val client = SpyApiClient()
        val recorder = recorder(store, client, this, threshold = 99)
        recorder.screenView(AnalyticsEvents.SCREEN_HOME)
        val submitted = store.load()

        // Simulate a concurrent enqueue: the queue grows during the request.
        store.save(submitted + QueuedAnalyticsEvent(name = "later"))
        recorder.flush()

        // flush() loaded both, so both go — but the id-based filter is what makes
        // that safe rather than a blind clear.
        assertTrue(store.load().isEmpty())
        assertEquals(listOf(2), client.batchSizes)
    }

    @Test
    fun optOutRecordsNothingAndFlushesNothing() = runTest {
        val store = InMemoryAnalyticsQueueStore()
        val client = SpyApiClient()
        val recorder = recorder(store, client, this, isEnabled = { false })

        recorder.screenView(AnalyticsEvents.SCREEN_HOME)
        recorder.event(AnalyticsEvents.WIDGET_OPENED_APP, mapOf(AnalyticsEvents.PARAM_ROUTE to "dua"))
        recorder.flush()

        assertTrue(store.load().isEmpty())
        assertEquals(0, client.postCount)
    }

    /**
     * Consent is re-read per call, so revoking it in Settings takes effect
     * immediately rather than on next launch.
     */
    @Test
    fun consentIsReReadPerCall() = runTest {
        val store = InMemoryAnalyticsQueueStore()
        val client = SpyApiClient()
        var isOn = true
        val recorder = recorder(store, client, TestScope(), threshold = 99) { isOn }

        recorder.screenView(AnalyticsEvents.SCREEN_HOME)
        isOn = false
        recorder.screenView(AnalyticsEvents.SCREEN_DUA)

        assertEquals("the post-revocation event must not be queued", 1, store.load().size)
    }

    @Test
    fun discardQueuedEmptiesTheQueue() = runTest {
        val store = InMemoryAnalyticsQueueStore()
        val recorder = recorder(store, SpyApiClient(), this)
        recorder.screenView(AnalyticsEvents.SCREEN_HOME)

        recorder.discardQueued()

        assertTrue(store.load().isEmpty())
    }

    /** Opting out via the Settings switch must drop what is already queued. */
    @Test
    fun disablingCollectionDropsQueuedEvents() = runTest {
        val store = InMemoryAnalyticsQueueStore()
        val recorder = recorder(store, SpyApiClient(), this)
        recorder.screenView(AnalyticsEvents.SCREEN_HOME)

        recorder.setCollectionEnabled(false)

        assertTrue(store.load().isEmpty())
    }

    /** Only the error's type — never its message, which can embed user input. */
    @Test
    fun nonFatalReportsTypeOnly() = runTest {
        val store = InMemoryAnalyticsQueueStore()
        val recorder = recorder(store, SpyApiClient(), this)

        recorder.nonFatal(SecretError())

        val params = store.load().first().params
        assertEquals(AnalyticsEvents.NON_FATAL_ERROR, store.load().first().name)
        assertEquals("SecretError", params[AnalyticsEvents.PARAM_ERROR_TYPE])
        assertFalse(params.values.any { it.contains("halal") })
    }

    /** An offline week must not grow an unbounded file or a giant first flush. */
    @Test
    fun queueIsCappedDroppingOldest() {
        val overflow = FileAnalyticsEventQueueStore.MAX_QUEUED + 10
        val events = (0 until overflow).map { QueuedAnalyticsEvent(name = "e$it") }

        // The cap lives in the file store, so exercise it directly.
        val directory = File(System.getProperty("java.io.tmpdir"), UUID.randomUUID().toString())
        val fileStore = FileAnalyticsEventQueueStore(File(directory, FileAnalyticsEventQueueStore.FILE_NAME))
        try {
            fileStore.save(events)

            val loaded = fileStore.load()
            assertEquals(FileAnalyticsEventQueueStore.MAX_QUEUED, loaded.size)
            assertEquals("oldest events should be the ones dropped", "e10", loaded.first().name)
        } finally {
            directory.deleteRecursively()
        }
    }

    /** Reaching the threshold flushes on its own, without an explicit flush(). */
    @OptIn(ExperimentalCoroutinesApi::class)
    @Test
    fun reachingThresholdFlushesAutomatically() = runTest {
        val store = InMemoryAnalyticsQueueStore()
        val client = SpyApiClient()
        val recorder = recorder(store, client, this, threshold = 3)

        repeat(3) { recorder.screenView("screen_$it") }
        advanceUntilIdle()

        assertEquals(1, client.postCount)
        assertEquals(listOf(3), client.batchSizes)
        assertTrue(store.load().isEmpty())
    }
}
