package com.fatwabot.core.prayer

import kotlinx.datetime.Instant

/** A single scheduled local notification — mirror of iOS PlannedNotification. */
data class PlannedNotification(
    val id: String,
    val prayer: PrayerNameUi,
    val kind: Kind,
    val fireEpochSeconds: Long,
    val titleKey: String,
    val bodyKey: String,
) {
    enum class Kind { ADHAN, PRE_ADHAN }
}

/** Per-prayer notification preferences (backend catalog-driven; ADR-0013). */
data class PrayerNotificationPreferences(
    val adhanEnabled: Set<PrayerNameUi> = PrayerNameUi.entries.filter { it.isPrayer }.toSet(),
    val preAdhanOffsetMinutes: Map<PrayerNameUi, Int> = emptyMap(),
)

/**
 * Pure builder for the rolling local-notification schedule — mirror of iOS
 * NotificationPlanner. No Android APIs, no clock reads; fully unit-testable.
 */
object NotificationPlanner {
    /** Android has no hard pending-alarm cap like iOS's 64, but we bound work anyway. */
    const val DEFAULT_BUDGET = 48

    fun plan(
        timeline: List<PrayerDayUi>,
        preferences: PrayerNotificationPreferences,
        now: Instant,
        budget: Int = DEFAULT_BUDGET,
    ): List<PlannedNotification> {
        val planned = mutableListOf<PlannedNotification>()
        val nowSeconds = now.epochSeconds

        for (day in timeline) {
            val key = "%04d%02d%02d".format(day.year, day.month, day.day)
            for (prayer in PrayerNameUi.entries) {
                if (!prayer.isPrayer) continue
                val prayerSeconds = day.times.getValue(prayer).epochSeconds

                if (prayer in preferences.adhanEnabled && prayerSeconds > nowSeconds) {
                    planned += PlannedNotification(
                        id = "adhan-$key-${prayer.name.lowercase()}",
                        prayer = prayer,
                        kind = PlannedNotification.Kind.ADHAN,
                        fireEpochSeconds = prayerSeconds,
                        titleKey = "notif.adhan.title.${prayer.name.lowercase()}",
                        bodyKey = "notif.adhan.body",
                    )
                }

                val offset = preferences.preAdhanOffsetMinutes[prayer] ?: 0
                if (offset > 0) {
                    val fire = prayerSeconds - offset * 60L
                    if (fire > nowSeconds) {
                        planned += PlannedNotification(
                            id = "pre-$key-${prayer.name.lowercase()}",
                            prayer = prayer,
                            kind = PlannedNotification.Kind.PRE_ADHAN,
                            fireEpochSeconds = fire,
                            titleKey = "notif.pre_adhan.title.${prayer.name.lowercase()}",
                            bodyKey = "notif.pre_adhan.body",
                        )
                    }
                }
            }
        }

        return planned.sortedBy { it.fireEpochSeconds }.take(budget)
    }
}
