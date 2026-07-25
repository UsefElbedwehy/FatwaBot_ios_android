package com.fatwabot.core.network

import com.fatwabot.core.common.AnalyticsEvents
import com.fatwabot.core.common.AnalyticsEventQueueStoring
import com.fatwabot.core.common.AnalyticsTracking
import com.fatwabot.core.common.QueuedAnalyticsEvent
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

@Serializable
private data class SubmitAnalyticsEventDto(
    @SerialName("client_event_id") val clientEventId: String,
    val name: String,
    @SerialName("occurred_at") val occurredAt: String,
    val platform: String,
    @SerialName("app_version") val appVersion: String,
    val params: Map<String, String>,
)

@Serializable
private data class SubmitAnalyticsRequest(val events: List<SubmitAnalyticsEventDto>)

// internal (not private) so tests can assert against it.
@Serializable
internal data class SubmitAnalyticsResponse(
    val accepted: Int,
    val duplicates: Int,
    val rejected: Int,
)

/**
 * [AnalyticsTracking] backed by our OWN ingest (`POST v1/analytics/events`) —
 * see docs/features/analytics-and-crash-reporting.md for why. Mirror of iOS
 * `BackendAnalyticsRecorder`.
 *
 * Unlike `GamificationEventRecorder`, which flushes on every `record` because
 * each event matters individually, this **batches**:
 * screen views are frequent and individually worthless, so posting one request
 * per screen change would burn battery and radio for nothing. Events accumulate
 * on disk and go out in one request once [batchThreshold] is reached, or when the
 * app launches / backgrounds ([flush]).
 *
 * On Android this is one half of a dual-send — the other half is Firebase, fanned
 * out by `CompositeAnalyticsTracking` in `:app`.
 */
class BackendAnalyticsRecorder(
    private val store: AnalyticsEventQueueStoring,
    private val client: AuthenticatedApiClientProtocol,
    private val appVersion: String,
    private val platform: String = "android",
    private val batchThreshold: Int = 20,
    private val scope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.IO),
    /**
     * Read fresh on every call, so revoking consent in Settings takes effect
     * immediately rather than on next launch. Backed by the same
     * `AnalyticsPreferences` the Firebase tracker uses — one switch governs both.
     */
    private val isEnabled: () -> Boolean,
) : AnalyticsTracking {
    private val json = Json { ignoreUnknownKeys = true }

    override fun screenView(screen: String) =
        event(AnalyticsEvents.SCREEN_VIEW, mapOf(AnalyticsEvents.PARAM_SCREEN to screen))

    override fun event(name: String, params: Map<String, String>) {
        if (!isEnabled()) return
        val queue = store.load() + QueuedAnalyticsEvent(name = name, params = params)
        store.save(queue)
        if (queue.size >= batchThreshold) scope.launch { flush() }
    }

    /**
     * Only the error's *type* is reported. A throwable's message can embed a URL,
     * a file path or user input, and this pipeline must not carry free text.
     */
    override fun nonFatal(error: Throwable) = event(
        AnalyticsEvents.NON_FATAL_ERROR,
        mapOf(AnalyticsEvents.PARAM_ERROR_TYPE to (error::class.simpleName ?: "Unknown")),
    )

    /**
     * Opting out drops anything queued but not yet sent, so pre-decision events
     * are never transmitted afterwards. Opting in needs no action — [isEnabled] is
     * re-read per call. There is no SDK here to toggle.
     */
    override fun setCollectionEnabled(enabled: Boolean) {
        if (!enabled) discardQueued()
    }

    /**
     * Sends everything currently queued in one batch. Call on launch and when the
     * app backgrounds. A failed flush leaves the queue intact for next time; the
     * ingest is idempotent per `client_event_id`, so a retry after a
     * partially-applied request never double-counts.
     */
    suspend fun flush() {
        if (!isEnabled()) return
        val pending = store.load()
        if (pending.isEmpty()) return

        val request = SubmitAnalyticsRequest(
            events = pending.map {
                SubmitAnalyticsEventDto(
                    clientEventId = it.clientEventId,
                    name = it.name,
                    occurredAt = it.occurredAt,
                    platform = platform,
                    appVersion = appVersion,
                    params = it.params,
                )
            },
        )
        runCatching {
            val body = json.encodeToString(SubmitAnalyticsRequest.serializer(), request)
            val raw = client.postRaw("v1/analytics/events", body)
            json.decodeFromString(SubmitAnalyticsResponse.serializer(), raw)
        }.onSuccess {
            // Drop only what we just submitted — more may have queued while this
            // flush was in flight.
            val submitted = pending.map { it.clientEventId }.toSet()
            store.save(store.load().filterNot { it.clientEventId in submitted })
        }
        // Silent by design: analytics must never surface an error to the user or
        // block anything. Stays queued for the next attempt.
    }

    /**
     * Drops anything not yet sent. Called when the user opts out, so queued
     * events from before the decision are never transmitted afterwards.
     */
    fun discardQueued() = store.save(emptyList())
}
