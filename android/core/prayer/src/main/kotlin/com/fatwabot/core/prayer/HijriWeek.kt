package com.fatwabot.core.prayer

import java.time.DayOfWeek
import java.time.LocalDate
import java.time.chrono.HijrahDate
import java.time.format.TextStyle
import java.time.temporal.ChronoField
import java.util.Locale

/**
 * The Hijri week strip shown in the الصلاة والتقويم widget. Mirror of iOS
 * `HijriWeek`.
 *
 * ## The strip can span a Hijri month boundary, and the header names only today's
 * Hijri months change on a different boundary from Gregorian weeks, so a week
 * containing a rollover genuinely reads `29 30 1 2`. The header comes from
 * **today's** Hijri date, so for part of such a week it names a month that some
 * trailing columns are no longer in.
 *
 * Deliberate rather than unhandled: the header answers "what is the date today",
 * which is what a reader glancing at the widget wants, and it agrees with every
 * other Hijri date in the app. Naming both months needs twice the width this row
 * has. If it is ever considered wrong, the fix is a per-column month, not a
 * different week anchor.
 */
data class HijriWeek(
    val monthName: String,
    val year: Int,
    val days: List<Day>,
) {
    data class Day(
        /** Hijri day-of-month. */
        val number: Int,
        /** Short weekday label, already localized. */
        val weekdayLabel: String,
        val isToday: Boolean,
    )

    companion object {
        /**
         * The seven days of the week containing [date].
         *
         * [offsetDays] matches the user's Hijri adjustment so the strip moves
         * with every other Hijri date in the app.
         */
        fun containing(
            date: LocalDate = LocalDate.now(),
            offsetDays: Long = 0,
            locale: Locale = Locale("ar"),
        ): HijriWeek {
            val today = date.plusDays(offsetDays)
            // Saturday-first, matching the Arabic convention the app renders in.
            val start = today.minusDays(
                ((today.dayOfWeek.value - DayOfWeek.SATURDAY.value) + 7).toLong() % 7,
            )
            val days = (0L..6L).map { offset ->
                val day = start.plusDays(offset)
                Day(
                    number = HijrahDate.from(day).get(ChronoField.DAY_OF_MONTH),
                    weekdayLabel = day.dayOfWeek.getDisplayName(TextStyle.NARROW, locale),
                    isToday = day == today,
                )
            }
            val hijriToday = HijrahDate.from(today)
            return HijriWeek(
                monthName = hijriMonthName(hijriToday, locale),
                year = hijriToday.get(ChronoField.YEAR),
                days = days,
            )
        }

        private fun hijriMonthName(date: HijrahDate, locale: Locale): String =
            java.time.format.DateTimeFormatter.ofPattern("MMMM", locale)
                .withChronology(date.chronology)
                .format(date)
    }
}
