package com.fatwabot.core.prayer

import java.time.DayOfWeek
import java.time.LocalDate
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** Mirrors iOS HijriWeekTests. */
class HijriWeekTest {

    @Test
    fun `a week has seven days and exactly one today`() {
        val week = HijriWeek.containing(LocalDate.of(2026, 8, 8))
        assertEquals(7, week.days.size)
        assertEquals(1, week.days.count { it.isToday })
    }

    @Test
    fun `the strip survives a hijri month boundary`() {
        // Walk a whole year. A month rollover is where a Gregorian-derived week
        // goes wrong, and it happens roughly monthly — one sampled date misses it.
        var day = LocalDate.of(2026, 1, 1)
        repeat(370) {
            val week = HijriWeek.containing(day)
            assertEquals(7, week.days.size)
            assertEquals(1, week.days.count { it.isToday })
            assertTrue(week.days.all { it.number in 1..30 })
            assertTrue(week.monthName.isNotBlank())
            day = day.plusDays(1)
        }
    }

    @Test
    fun `the week starts on saturday`() {
        // Arabic convention, and the labels must sit above their own columns.
        var day = LocalDate.of(2026, 8, 1)
        repeat(14) {
            val week = HijriWeek.containing(day)
            val todayIndex = week.days.indexOfFirst { it.isToday }
            val expectedIndex = ((day.dayOfWeek.value - DayOfWeek.SATURDAY.value) + 7) % 7
            assertEquals(expectedIndex, todayIndex)
            day = day.plusDays(1)
        }
    }

    @Test
    fun `hijri offset moves the strip`() {
        val base = HijriWeek.containing(LocalDate.of(2026, 8, 8))
        val shifted = HijriWeek.containing(LocalDate.of(2026, 8, 8), offsetDays = 1)
        assertTrue(
            base.days.first { it.isToday }.number != shifted.days.first { it.isToday }.number,
        )
    }

    @Test
    fun `a week spanning a month rollover keeps today's month in the header`() {
        // Documented behaviour, so asserted rather than left to a comment. On a
        // rollover week the header must name the month *today* is in, computed
        // independently here — not read back from the value under test.
        var day = LocalDate.of(2026, 1, 1)
        var checked = 0
        repeat(370) {
            val week = HijriWeek.containing(day)
            val numbers = week.days.map { it.number }
            if (numbers.zipWithNext().any { (a, b) -> b < a }) {
                val expected = java.time.format.DateTimeFormatter
                    .ofPattern("MMMM", java.util.Locale("ar"))
                    .withChronology(java.time.chrono.HijrahChronology.INSTANCE)
                    .format(java.time.chrono.HijrahDate.from(day))
                assertEquals(expected, week.monthName)
                // And the strip genuinely does carry both months' days.
                assertTrue(numbers.contains(1))
                checked++
            }
            day = day.plusDays(1)
        }
        // Rollovers happen ~monthly; if none were found the test proved nothing.
        assertTrue("expected to encounter rollover weeks", checked > 10)
    }
}
