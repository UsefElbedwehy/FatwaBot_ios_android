package com.fatwabot.core.prayer

import java.io.File
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/**
 * The data widgets render from — written by the app, read by the Glance widget
 * with zero network (mirror of iOS PrayerWidgetSnapshot). Precomputed 48h ahead.
 */
@Serializable
data class PrayerWidgetSnapshot(
    val locationName: String,
    val hijriMonthName: String,
    val hijriDay: Int,
    val hijriYear: Int,
    val upcoming: List<Entry>,
    val generatedAtEpochSeconds: Long,
) {
    @Serializable
    data class Entry(val prayer: String, val timeEpochSeconds: Long)

    fun nextEntry(afterEpochSeconds: Long): Entry? =
        upcoming.firstOrNull { it.timeEpochSeconds > afterEpochSeconds }

    companion object {
        fun build(
            timeline: List<PrayerDayUi>,
            location: String,
            hijri: HijriDateUi,
            generatedAtEpochSeconds: Long,
            horizonSeconds: Long = 48 * 3600,
        ): PrayerWidgetSnapshot {
            val cutoff = generatedAtEpochSeconds + horizonSeconds
            val entries = timeline
                .flatMap { day -> day.ordered.filter { it.first.isPrayer } }
                .map { Entry(it.first.name.lowercase(), it.second.epochSeconds) }
                .filter { it.timeEpochSeconds <= cutoff }
                .sortedBy { it.timeEpochSeconds }
            return PrayerWidgetSnapshot(
                location, hijri.monthName, hijri.day, hijri.year, entries, generatedAtEpochSeconds,
            )
        }
    }
}

/** File-backed store (app files dir shared with the widget process). */
class WidgetSnapshotStore(private val file: File) {
    private val json = Json { ignoreUnknownKeys = true }

    fun write(snapshot: PrayerWidgetSnapshot) {
        runCatching {
            file.parentFile?.mkdirs()
            val tmp = File(file.parentFile, "${file.name}.tmp")
            tmp.writeText(json.encodeToString(PrayerWidgetSnapshot.serializer(), snapshot))
            tmp.renameTo(file)
        }
    }

    fun read(): PrayerWidgetSnapshot? = runCatching {
        if (!file.exists()) null else json.decodeFromString<PrayerWidgetSnapshot>(file.readText())
    }.getOrNull()
}
