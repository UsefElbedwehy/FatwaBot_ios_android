package com.fatwabot.feature.gamification

import com.fatwabot.core.common.ActivityEventRecording
import com.fatwabot.core.common.WorshipInbox
import com.fatwabot.core.network.AuthenticatedApiClientProtocol
import java.time.Instant
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

@Serializable
private data class SubmitEventDto(
    @SerialName("client_event_id") val clientEventId: String,
    @SerialName("event_type") val eventType: String,
    @SerialName("occurred_at") val occurredAt: String,
    val timezone: String,
    val metadata: Map<String, String>,
)

@Serializable
private data class SubmitEventsRequest(val events: List<SubmitEventDto>)

@Serializable
internal data class SubmitEventsResponse(val accepted: Int, val duplicates: Int)

/** Concrete ActivityEventRecording — the thing Tasbeeh/Azkar/Awrad/Hadith are
 * actually injected with. Queues locally first (so `record` never blocks or
 * fails visibly to the caller), then flushes opportunistically; a failed
 * flush just leaves events queued for next time. */
class GamificationEventRecorder(
    private val store: ActivityEventQueueStoring,
    private val client: AuthenticatedApiClientProtocol,
    private val scope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.IO),
) : ActivityEventRecording {
    private val json = Json { ignoreUnknownKeys = true }

    override fun record(eventType: String, metadata: Map<String, String>) {
        val queue = store.load() + QueuedActivityEvent(
            eventType = eventType,
            occurredAtEpochSeconds = Instant.now().epochSecond,
            timezone = java.util.TimeZone.getDefault().id,
            metadata = metadata,
        )
        store.save(queue)
        scope.launch { flush() }
    }

    /**
     * Takes ownership of worship logged outside the app (the متابعة العبادات
     * widget) and clears it from the inbox. Mirror of iOS `drain`.
     *
     * ## Why the ids are preserved rather than re-minted
     * [record] generates a fresh `clientEventId`. Using it here would defeat the
     * inbox's idempotency: the id minted at the tap is what makes a re-run safe,
     * and replacing it means a drain that runs twice submits the same prayer
     * under two ids and counts it twice.
     *
     * ## Why enqueue happens before clear
     * Crashing between the two leaves the entry in both places, and the backend
     * dedupes on client_event_id — so the deed counts once. Clearing first and
     * crashing loses it outright. Between a duplicate the server already
     * collapses and a silently dropped act of worship, only one ordering is
     * defensible.
     */
    suspend fun drain(inbox: WorshipInbox) {
        val entries = inbox.peek()
        if (entries.isEmpty()) return

        val queue = store.load()
        val known = queue.map { it.clientEventId }.toSet()
        store.save(
            queue + entries.filterNot { it.clientEventId in known }.map {
                QueuedActivityEvent(
                    clientEventId = it.clientEventId,
                    eventType = it.eventType,
                    occurredAtEpochSeconds = it.occurredAtEpochSeconds,
                    timezone = it.timezone,
                    metadata = it.metadata,
                )
            },
        )
        inbox.clear(entries)

        flush()
    }

    /** Submits every currently-queued event in one batch (the backend ingest is
     * idempotent per client_event_id, so a partial-failure retry never
     * double-counts). Clears the queue only after a confirmed round-trip. */
    suspend fun flush() {
        val pending = store.load()
        if (pending.isEmpty()) return

        val request = SubmitEventsRequest(
            events = pending.map {
                SubmitEventDto(
                    clientEventId = it.clientEventId,
                    eventType = it.eventType,
                    occurredAt = Instant.ofEpochSecond(it.occurredAtEpochSeconds).toString(),
                    timezone = it.timezone,
                    metadata = it.metadata,
                )
            },
        )
        runCatching {
            val body = json.encodeToString(SubmitEventsRequest.serializer(), request)
            val raw = client.postRaw("v1/gamification/events", body)
            json.decodeFromString(SubmitEventsResponse.serializer(), raw)
        }.onSuccess {
            val pendingIds = pending.map { it.clientEventId }.toSet()
            val stillPending = store.load().filterNot { it.clientEventId in pendingIds }
            store.save(stillPending)
        }
        // Silent failure (docs/features/gamification.md): stays queued, retried on next record() or app launch.
    }
}
