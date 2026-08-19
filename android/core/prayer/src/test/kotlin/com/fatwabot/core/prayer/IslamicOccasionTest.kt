package com.fatwabot.core.prayer

import java.time.LocalDate
import java.time.chrono.HijrahDate
import java.time.temporal.ChronoField
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** Mirrors iOS IslamicOccasionTests. */
class IslamicOccasionTest {

    @Test
    fun `each occasion lands on its hijri date`() {
        // The load-bearing assertion: whatever Gregorian day we compute, it must
        // actually *be* 1 Ramadan / 1 Shawwal / 10 Dhu al-Hijja.
        IslamicOccasion.entries.forEach { occasion ->
            val result = IslamicOccasionCalculator.countdown(occasion, LocalDate.of(2026, 8, 8))
            val hijri = HijrahDate.from(result.gregorianDate)
            assertEquals(occasion.hijriMonth, hijri.get(ChronoField.MONTH_OF_YEAR))
            assertEquals(occasion.hijriDay, hijri.get(ChronoField.DAY_OF_MONTH))
        }
    }

    @Test
    fun `countdown is never negative`() {
        // Asking on 15 Ramadan must not answer -14. Swept across a whole year so
        // no single lucky date can pass this.
        var day = LocalDate.of(2026, 1, 1)
        repeat(370) {
            IslamicOccasion.entries.forEach { occasion ->
                val result = IslamicOccasionCalculator.countdown(occasion, day)
                assertTrue(result.daysRemaining >= 0)
                assertTrue(result.daysRemaining < 366)
            }
            day = day.plusDays(1)
        }
    }

    @Test
    fun `an occasion beginning today reads zero rather than next year`() {
        val ramadan = IslamicOccasionCalculator.countdown(
            IslamicOccasion.RAMADAN, LocalDate.of(2026, 8, 8),
        )
        val onTheDay = IslamicOccasionCalculator.countdown(
            IslamicOccasion.RAMADAN, ramadan.gregorianDate,
        )
        assertEquals(0L, onTheDay.daysRemaining)
    }

    @Test
    fun `countdown shrinks by one each day`() {
        val start = LocalDate.of(2026, 8, 8)
        val today = IslamicOccasionCalculator.countdown(IslamicOccasion.RAMADAN, start)
        val tomorrow = IslamicOccasionCalculator.countdown(IslamicOccasion.RAMADAN, start.plusDays(1))
        assertEquals(today.daysRemaining - 1, tomorrow.daysRemaining)
    }

    @Test
    fun `all is sorted by proximity`() {
        val all = IslamicOccasionCalculator.all(LocalDate.of(2026, 8, 8))
        assertEquals(3, all.size)
        assertEquals(all.map { it.daysRemaining }.sorted(), all.map { it.daysRemaining })
    }

    @Test
    fun `hijri offset shifts the countdown`() {
        val base = IslamicOccasionCalculator.countdown(IslamicOccasion.RAMADAN, LocalDate.of(2026, 8, 8))
        val shifted = IslamicOccasionCalculator.countdown(
            IslamicOccasion.RAMADAN, LocalDate.of(2026, 8, 8), offsetDays = 1,
        )
        // A user who adjusted their Hijri date must not see a countdown computed
        // off the unadjusted calendar sitting next to it.
        assertEquals(base.daysRemaining - 1, shifted.daysRemaining)
    }

    @Test
    fun `pinned against a known reference date`() {
        // Cross-platform parity asserted, not assumed: iOS uses Foundation's
        // islamicUmmAlQura and this uses HijrahChronology — two independent
        // implementations that could silently diverge by a day. The identical
        // values are pinned in the iOS test.
        //
        // Independently corroborated: these are the figures a published Umm
        // al-Qura calendar shows for this date.
        val from = LocalDate.of(2026, 8, 8)
        assertEquals(184L, IslamicOccasionCalculator.countdown(IslamicOccasion.RAMADAN, from).daysRemaining)
        assertEquals(213L, IslamicOccasionCalculator.countdown(IslamicOccasion.EID_AL_FITR, from).daysRemaining)
        assertEquals(281L, IslamicOccasionCalculator.countdown(IslamicOccasion.EID_AL_ADHA, from).daysRemaining)
        assertEquals(
            LocalDate.of(2027, 2, 8),
            IslamicOccasionCalculator.countdown(IslamicOccasion.RAMADAN, from).gregorianDate,
        )
    }
}
