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
}
