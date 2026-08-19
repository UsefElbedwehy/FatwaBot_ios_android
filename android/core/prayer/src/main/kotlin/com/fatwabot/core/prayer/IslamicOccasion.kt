package com.fatwabot.core.prayer

import java.time.LocalDate
import java.time.chrono.HijrahChronology
import java.time.chrono.HijrahDate
import java.time.temporal.ChronoField
import java.time.temporal.ChronoUnit

/**
 * Days remaining until Ramadan and the two Eids. Mirror of iOS
 * `IslamicOccasionCalculator`.
 *
 * ## What this number is, and is not
 * Arithmetic over the **Umm al-Qura** calendar (`HijrahChronology.INSTANCE`),
 * the same calendar the rest of the app's Hijri dates come from. The actual
 * start of Ramadan is determined by moon sighting in each country, so this can
 * legitimately differ from the announced date by a day. The widget presents a
 * countdown, not a ruling — a precise announced date would need a sighting
 * source, not this file.
 */
enum class IslamicOccasion(val hijriMonth: Int, val hijriDay: Int) {
    RAMADAN(9, 1),
    EID_AL_FITR(10, 1),
    EID_AL_ADHA(12, 10),
}

data class IslamicOccasionCountdown(
    val occasion: IslamicOccasion,
    /** Whole days from the query date. Zero means it begins today. */
    val daysRemaining: Long,
    /** The Gregorian day the occasion falls on, per Umm al-Qura. */
    val gregorianDate: LocalDate,
)

object IslamicOccasionCalculator {
    /**
     * Countdown to [occasion] from [from].
     *
     * [offsetDays] is the user's Hijri adjustment, applied the same way the rest
     * of the app applies it, so the countdown and the displayed Hijri date
     * cannot disagree.
     *
     * ## Why the target is the *next* occurrence
     * Asking for "days until Ramadan" on 15 Ramadan must not answer -14. If this
     * Hijri year's date has already passed, the search moves to the next year,
     * so the number is always forward-looking.
     */
    fun countdown(
        occasion: IslamicOccasion,
        from: LocalDate = LocalDate.now(),
        offsetDays: Long = 0,
    ): IslamicOccasionCountdown {
        val today = from.plusDays(offsetDays)
        val todayHijri = HijrahDate.from(today)
        var year = todayHijri.get(ChronoField.YEAR)

        var target = hijriDate(year, occasion)
        // `isBefore` and not `isAfter`: an occasion beginning *today* must read
        // 0, not roll forward a whole year and tell a fasting user Ramadan is
        // most of a year away on its first morning.
        if (target.isBefore(today)) {
            year += 1
            target = hijriDate(year, occasion)
        }

        val days = ChronoUnit.DAYS.between(today, target).coerceAtLeast(0)
        return IslamicOccasionCountdown(
            occasion = occasion,
            daysRemaining = days,
            // Shift back so a user with a +1 offset sees the date their own
            // calendar shows.
            gregorianDate = target.minusDays(offsetDays),
        )
    }

    private fun hijriDate(year: Int, occasion: IslamicOccasion): LocalDate =
        LocalDate.from(
            HijrahChronology.INSTANCE.date(year, occasion.hijriMonth, occasion.hijriDay),
        )

    /** All three, nearest first. */
    fun all(from: LocalDate = LocalDate.now(), offsetDays: Long = 0): List<IslamicOccasionCountdown> =
        IslamicOccasion.entries
            .map { countdown(it, from, offsetDays) }
            .sortedBy { it.daysRemaining }
}
