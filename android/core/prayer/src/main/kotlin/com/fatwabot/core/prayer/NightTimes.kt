package com.fatwabot.core.prayer

/**
 * The two night markers derived from a night's span: منتصف الليل and الثلث الأخير.
 * Mirror of iOS `NightTimes`.
 *
 * ## Why this is its own type
 * The last third was computed inline in [NotificationPlanner] and is now also
 * displayed by the day-sheet widget. Two copies of the arithmetic would be two
 * definitions of a religious time that must agree — the widget saying 1:39 and
 * the notification firing at 1:47 is not a rounding difference to a user, it is
 * the app contradicting itself about when qiyam begins.
 *
 * ## The definition
 * The night runs from **Maghrib to the following day's Fajr** — not to clock
 * midnight, and not from Isha. Midnight is its midpoint; the last third begins
 * two-thirds of the way through. Integer arithmetic throughout, matching what
 * the planner already shipped, so no existing notification time shifts by a
 * second as a side effect of this refactor.
 */
data class NightTimes(
    /** منتصف الليل — the midpoint of the night, not 00:00 clock time. */
    val midnightEpochSeconds: Long,
    /** الثلث الأخير — where the final third of the night begins. */
    val lastThirdEpochSeconds: Long,
) {
    companion object {
        /**
         * Night markers for the span `maghrib until nextFajr`, or null when that
         * is not a real night.
         *
         * At extreme latitudes the calculator can place Fajr before the
         * preceding Maghrib; a negative night length yields markers that run
         * backwards through the evening — a wrong time presented with total
         * confidence. Absent is the honest answer, and every caller already
         * handles "no next day".
         */
        fun between(maghribEpochSeconds: Long, nextFajrEpochSeconds: Long): NightTimes? {
            if (nextFajrEpochSeconds <= maghribEpochSeconds) return null
            val length = nextFajrEpochSeconds - maghribEpochSeconds
            return NightTimes(
                midnightEpochSeconds = maghribEpochSeconds + length / 2L,
                lastThirdEpochSeconds = maghribEpochSeconds + length * 2L / 3L,
            )
        }
    }
}
