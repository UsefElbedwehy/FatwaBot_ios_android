package com.fatwabot.core.prayer

import kotlinx.datetime.Instant
import kotlinx.serialization.Serializable

/** A single scheduled local notification — mirror of iOS PlannedNotification. */
data class PlannedNotification(
    val id: String,
    val prayer: PrayerNameUi?, // null for night-based notifications (last third)
    val kind: Kind,
    val fireEpochSeconds: Long,
    val titleKey: String,
    val bodyKey: String,
) {
    enum class Kind { ADHAN, PRE_ADHAN, IQAMA, LAST_THIRD }
}

/**
 * User-facing notification preferences (docs/PRODUCT_REQUIREMENTS_2026-07.md) —
 * mirror of iOS PrayerNotificationPreferences. Every type is individually
 * toggleable; offsets are user-set. Serializable for persistence.
 */
@Serializable
data class PrayerNotificationPreferences(
    val adhanEnabled: Boolean = true,
    val preAdhanEnabled: Boolean = true,
    val preAdhanOffsetMinutes: Int = 10,
    val iqamaEnabled: Boolean = false,
    /**
     * Iqama gap in minutes AFTER the adhan, **per prayer** — mosques don't use a
     * single figure, Fajr typically waits longer than the rest. Keyed by
     * [PrayerNameUi.key] ("fajr", "dhuhr", …) so the stored values line up with
     * the iOS `iqamaOffsetsByPrayer` dictionary. Sunrise is not a prayer and
     * never gets one.
     */
    val iqamaOffsetsByPrayer: Map<String, Int> = DEFAULT_IQAMA_OFFSETS,
    val lastThirdEnabled: Boolean = false,
) {
    val clampedPreAdhan: Int get() = clamp(preAdhanOffsetMinutes)

    /**
     * Gap for one prayer, falling back to the mosque default so a partially
     * populated map can never silently drop a prayer's reminder.
     */
    fun iqamaOffset(prayer: PrayerNameUi): Int = clamp(
        iqamaOffsetsByPrayer[prayer.key]
            ?: DEFAULT_IQAMA_OFFSETS[prayer.key]
            ?: DEFAULT_IQAMA_OFFSET_MINUTES,
    )

    /** Copy with one prayer's gap replaced (clamped) — the settings steppers' setter. */
    fun withIqamaOffset(prayer: PrayerNameUi, minutes: Int): PrayerNotificationPreferences =
        copy(iqamaOffsetsByPrayer = iqamaOffsetsByPrayer + (prayer.key to clamp(minutes)))

    companion object {
        const val OFFSET_MIN = 1
        const val OFFSET_MAX = 60

        /** Mosque convention (confirmed with the owner): Fajr waits longer. */
        const val FAJR_IQAMA_OFFSET_MINUTES = 20
        const val DEFAULT_IQAMA_OFFSET_MINUTES = 10

        val DEFAULT_IQAMA_OFFSETS: Map<String, Int> = PrayerNameUi.entries
            .filter { it.isPrayer }
            .associate { prayer ->
                prayer.key to if (prayer == PrayerNameUi.FAJR) {
                    FAJR_IQAMA_OFFSET_MINUTES
                } else {
                    DEFAULT_IQAMA_OFFSET_MINUTES
                }
            }

        fun clamp(minutes: Int): Int = minutes.coerceIn(OFFSET_MIN, OFFSET_MAX)
    }
}

/**
 * Pure builder for the rolling local-notification schedule — mirror of iOS
 * NotificationPlanner. No Android APIs, no clock reads; fully unit-testable.
 */
object NotificationPlanner {
    const val DEFAULT_BUDGET = 48

    fun plan(
        timeline: List<PrayerDayUi>,
        preferences: PrayerNotificationPreferences,
        now: Instant,
        budget: Int = DEFAULT_BUDGET,
    ): List<PlannedNotification> {
        val planned = mutableListOf<PlannedNotification>()
        val nowSeconds = now.epochSeconds

        for ((index, day) in timeline.withIndex()) {
            val key = "%04d%02d%02d".format(day.year, day.month, day.day)
            for (prayer in PrayerNameUi.entries) {
                if (!prayer.isPrayer) continue
                val prayerSeconds = day.times.getValue(prayer).epochSeconds
                val lower = prayer.key

                if (preferences.adhanEnabled && prayerSeconds > nowSeconds) {
                    planned += PlannedNotification(
                        id = "adhan-$key-$lower", prayer = prayer,
                        kind = PlannedNotification.Kind.ADHAN, fireEpochSeconds = prayerSeconds,
                        titleKey = "notif.adhan.title.$lower", bodyKey = "notif.adhan.body",
                    )
                }

                if (preferences.preAdhanEnabled) {
                    val fire = prayerSeconds - preferences.clampedPreAdhan * 60L
                    if (fire > nowSeconds) {
                        planned += PlannedNotification(
                            id = "pre-$key-$lower", prayer = prayer,
                            kind = PlannedNotification.Kind.PRE_ADHAN, fireEpochSeconds = fire,
                            titleKey = "notif.pre_adhan.title.$lower", bodyKey = "notif.pre_adhan.body",
                        )
                    }
                }

                // Iqama reminder — a per-prayer number of minutes after the adhan.
                // Sunrise is excluded above (isPrayer); Fajr..Isha all get one.
                if (preferences.iqamaEnabled) {
                    val fire = prayerSeconds + preferences.iqamaOffset(prayer) * 60L
                    if (fire > nowSeconds) {
                        planned += PlannedNotification(
                            id = "iqama-$key-$lower", prayer = prayer,
                            kind = PlannedNotification.Kind.IQAMA, fireEpochSeconds = fire,
                            titleKey = "notif.iqama.title.$lower", bodyKey = "notif.iqama.body",
                        )
                    }
                }
            }

            // Last third of the night: Maghrib(day) → Fajr(day+1), final third.
            if (preferences.lastThirdEnabled && index + 1 < timeline.size) {
                val maghrib = day.times.getValue(PrayerNameUi.MAGHRIB).epochSeconds
                val fajrNext = timeline[index + 1].times.getValue(PrayerNameUi.FAJR).epochSeconds
                if (fajrNext > maghrib) {
                    val start = maghrib + ((fajrNext - maghrib) * 2L / 3L)
                    if (start > nowSeconds) {
                        planned += PlannedNotification(
                            id = "lastthird-$key", prayer = null,
                            kind = PlannedNotification.Kind.LAST_THIRD, fireEpochSeconds = start,
                            titleKey = "notif.last_third.title", bodyKey = "notif.last_third.body",
                        )
                    }
                }
            }
        }

        return planned.sortedBy { it.fireEpochSeconds }.take(budget)
    }
}
