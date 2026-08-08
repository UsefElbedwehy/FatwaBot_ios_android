package com.fatwabot.core.common

import java.io.File
import java.util.UUID
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/**
 * One worship action logged from outside the app — currently the interactive
 * متابعة العبادات widget. Mirror of iOS `WorshipInboxEntry`.
 */
@Serializable
data class WorshipInboxEntry(
    /**
     * Idempotency key, generated at the tap rather than at drain time, so a
     * drain interrupted after upload but before deletion resubmits the *same*
     * id and the server dedupes it rather than double-counting the deed.
     */
    val clientEventId: String = UUID.randomUUID().toString(),
    val eventType: String,
    val occurredAtEpochSeconds: Long,
    val timezone: String = java.util.TimeZone.getDefault().id,
    val metadata: Map<String, String> = emptyMap(),
)

/**
 * A drop-box the widget writes to and the app drains. Mirror of iOS
 * `WorshipInbox`.
 *
 * ## Why not just append to the existing activity-event queue
 * `ActivityEventQueueStoring` persists the whole list through `save()`. Two
 * processes doing read-modify-write on one file is a lost update, and the thing
 * lost is a user's record of an act of worship — the app would show a streak
 * broken on a day they had in fact prayed.
 *
 * ## Why one file per entry
 * Each deposit creates its own uniquely-named file, so there is **no shared
 * mutable state to race on**: the widget only ever creates, the app only ever
 * reads-then-deletes. Costs an inode per tap and buys a design where concurrent
 * writers cannot drop each other's work.
 *
 * ## Ordering
 * [peek] sorts by time rather than trusting directory order, which is
 * unspecified — exactly the kind of thing that behaves in a test and differs on
 * a device.
 */
class WorshipInbox(private val directory: File) {
    private val json = Json { ignoreUnknownKeys = true }

    /**
     * Records one action. Best-effort by design: a widget tap has no UI in which
     * to report a filesystem failure.
     */
    fun deposit(entry: WorshipInboxEntry): Boolean = runCatching {
        directory.mkdirs()
        // Named by the event id, so a retried deposit overwrites rather than
        // duplicating.
        File(directory, "${entry.clientEventId}.json")
            .writeText(json.encodeToString(WorshipInboxEntry.serializer(), entry))
        true
    }.getOrDefault(false)

    /**
     * Everything deposited since the last clear, oldest first.
     *
     * Does **not** delete — see [clear]. Splitting read from delete lets the app
     * discard only what it actually accepted; a destructive drain would lose
     * every entry in a batch whose upload failed.
     */
    fun peek(): List<WorshipInboxEntry> =
        (directory.listFiles()?.toList() ?: emptyList())
            .filter { it.extension == "json" }
            .mapNotNull { file ->
                // One unreadable file must not cost the user every other deed.
                runCatching {
                    json.decodeFromString(WorshipInboxEntry.serializer(), file.readText())
                }.getOrNull()
            }
            .sortedBy { it.occurredAtEpochSeconds }

    /** Discards the named entries. Unknown ids are ignored, so a double clear is harmless. */
    fun clear(entries: List<WorshipInboxEntry>) {
        entries.forEach { runCatching { File(directory, "${it.clientEventId}.json").delete() } }
    }

    companion object {
        private const val DIRECTORY_NAME = "worship-inbox"

        /**
         * The one place the inbox location is decided. The widget writes and the
         * app drains; if those two ever disagreed about the path, taps would
         * accumulate in a directory nothing reads and no error would say so.
         */
        fun default(filesDir: File): WorshipInbox = WorshipInbox(File(filesDir, DIRECTORY_NAME))
    }
}

/**
 * The deeds the متابعة العبادات tracker can log. Mirror of iOS `WorshipDeed`.
 *
 * Shared between the widget (which writes them) and the app (which drains and
 * uploads them) so the two cannot drift: a widget writing `"azkar_morning"`
 * against an app expecting `"morning_azkar"` would log deeds that silently never
 * count toward a streak.
 */
enum class WorshipDeed(val key: String) {
    FAJR("fajr"),
    DHUHR("dhuhr"),
    ASR("asr"),
    MAGHRIB("maghrib"),
    ISHA("isha"),
    AZKAR_MORNING("azkar_morning"),
    AZKAR_EVENING("azkar_evening"),
    ;

    /**
     * The event type this deed is submitted as, matching what the app already
     * records from its own screens — so a prayer logged from the widget and one
     * logged in-app are indistinguishable to the streak engine.
     */
    val eventType: String
        get() = when (this) {
            AZKAR_MORNING, AZKAR_EVENING -> "azkar_completed"
            else -> "prayer_completed"
        }

    val metadata: Map<String, String>
        get() = when (this) {
            AZKAR_MORNING -> mapOf("category" to "morning")
            AZKAR_EVENING -> mapOf("category" to "evening")
            else -> mapOf("prayer" to key)
        }

    companion object {
        /** The five obligatory prayers, in order. */
        val prayers: List<WorshipDeed> = listOf(FAJR, DHUHR, ASR, MAGHRIB, ISHA)

        fun fromKey(key: String): WorshipDeed? = entries.firstOrNull { it.key == key }
    }
}
