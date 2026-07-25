package com.fatwabot.core.common

import java.io.File
import java.time.Instant
import java.util.UUID
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json

/**
 * One queued analytics event. [clientEventId] is what makes the ingest
 * idempotent — a flush that fails after the server committed can be retried
 * without double-counting.
 *
 * [occurredAt] is held as an ISO-8601 instant string so what is on disk is
 * already what goes on the wire (mirrors the iOS `QueuedAnalyticsEvent`, which
 * encodes its `Date` with `.iso8601`).
 */
@Serializable
data class QueuedAnalyticsEvent(
    @SerialName("client_event_id") val clientEventId: String = UUID.randomUUID().toString(),
    val name: String,
    val params: Map<String, String> = emptyMap(),
    @SerialName("occurred_at") val occurredAt: String = Instant.now().toString(),
)

/** Persistence boundary for the queue (mirrors ActivityEventQueueStoring). */
interface AnalyticsEventQueueStoring {
    fun load(): List<QueuedAnalyticsEvent>
    fun save(events: List<QueuedAnalyticsEvent>)
}

/**
 * Disk-backed queue so events survive a cold start and an offline stretch —
 * mirrors `FileActivityEventQueueStore`.
 *
 * The queue is **capped**: analytics is the least important thing the app does,
 * so a user who is offline for a week must not accumulate an unbounded file (or
 * a giant first flush). Oldest events are dropped once the cap is reached.
 */
class FileAnalyticsEventQueueStore(private val file: File) : AnalyticsEventQueueStoring {
    private val json = Json { ignoreUnknownKeys = true }
    private val serializer = ListSerializer(QueuedAnalyticsEvent.serializer())

    override fun load(): List<QueuedAnalyticsEvent> = runCatching {
        if (!file.exists()) emptyList() else json.decodeFromString(serializer, file.readText())
    }.getOrDefault(emptyList())

    override fun save(events: List<QueuedAnalyticsEvent>) {
        val trimmed = if (events.size > MAX_QUEUED) events.takeLast(MAX_QUEUED) else events
        runCatching {
            file.parentFile?.mkdirs()
            val tmp = File(file.parentFile, "${file.name}.tmp")
            tmp.writeText(json.encodeToString(serializer, trimmed))
            tmp.renameTo(file)
        }
    }

    companion object {
        const val MAX_QUEUED = 500
        const val FILE_NAME = "analytics-event-queue.json"
    }
}
