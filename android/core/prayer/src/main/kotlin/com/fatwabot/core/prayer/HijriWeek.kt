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
 * ## Why the header comes from the Hijri calendar
 * A Gregorian week spanning a Hijri month change produces `29 30 1 2`, and a
 * header derived from anything but the Hijri date of *today* would name the
 * wrong month for half the strip.
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
