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
    /**
     * Full day sheets over the same horizon, for the widgets that show the whole
     * day rather than the next prayer.
     *
     * Defaulted, and declared last, so a snapshot written by a previous app
     * version still deserializes. The widget process can be running the new build
     * against whatever the app last wrote; without the default that is a parse
     * failure, `read()` returns null, and every prayer widget on the home screen
     * falls back to its placeholder until the user next opens the app.
     */
    val days: List<DaySheet> = emptyList(),
) {
    @Serializable
    data class Entry(val prayer: String, val timeEpochSeconds: Long)

    /**
     * A whole day as the day-sheet widgets render it.
     *
     * Separate from [upcoming] rather than folded into it, because the two answer
     * different questions and merging them breaks one: the countdown widgets ask
     * "what is the next *prayer*", and sunrise is a displayed time but not a
     * prayer — putting it in [upcoming] would make the home screen announce
     * الشروق as the next prayer every morning.
     */
    @Serializable
    data class DaySheet(
        /** This day's Fajr — both the first row and the key this sheet is selected by. */
        val fajrEpochSeconds: Long,
        /** Every time in display order, sunrise included. */
        val times: List<Entry>,
        /**
         * Null when the following day was beyond the snapshot horizon, or at
         * latitudes where the night has no valid span (see [NightTimes]).
         */
        val midnightEpochSeconds: Long? = null,
        val lastThirdEpochSeconds: Long? = null,
    )

    fun nextEntry(afterEpochSeconds: Long): Entry? =
        upcoming.firstOrNull { it.timeEpochSeconds > afterEpochSeconds }

    /**
     * The day sheet covering [atEpochSeconds].
     *
     * Selected by the latest Fajr at or before the instant, which deliberately
     * keeps the *previous* day's sheet on screen through the small hours: at
     * 01:00 the night markers a reader cares about — منتصف الليل and الثلث الأخير
     * — belong to the night that began at yesterday's Maghrib and are still ahead
     * of them. Rolling over at clock midnight would blank exactly the two rows
     * the widget exists to show, at exactly the hour someone is up to read them.
     */
    fun sheet(atEpochSeconds: Long): DaySheet? =
        days.lastOrNull { it.fajrEpochSeconds <= atEpochSeconds } ?: days.firstOrNull()

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

            // Day sheets keep every time, sunrise included — the opposite of the
            // isPrayer filter above, and the reason this is a second pass rather
            // than a reshaping of `entries`.
            val sheets = timeline.mapIndexedNotNull { index, day ->
                val fajr = day.times.getValue(PrayerNameUi.FAJR).epochSeconds
                if (fajr > cutoff) return@mapIndexedNotNull null
                val night = if (index + 1 < timeline.size) {
                    NightTimes.between(
                        maghribEpochSeconds = day.times.getValue(PrayerNameUi.MAGHRIB).epochSeconds,
                        nextFajrEpochSeconds =
                            timeline[index + 1].times.getValue(PrayerNameUi.FAJR).epochSeconds,
                    )
                } else {
                    null
                }
                DaySheet(
                    fajrEpochSeconds = fajr,
                    times = day.ordered.map {
                        Entry(it.first.name.lowercase(), it.second.epochSeconds)
                    },
                    midnightEpochSeconds = night?.midnightEpochSeconds,
                    lastThirdEpochSeconds = night?.lastThirdEpochSeconds,
                )
            }

            return PrayerWidgetSnapshot(
                location, hijri.monthName, hijri.day, hijri.year, entries,
                generatedAtEpochSeconds, sheets,
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
