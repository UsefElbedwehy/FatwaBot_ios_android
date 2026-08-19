package com.fatwabot.widget

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class WidgetDuaPoolTest {

    @Test
    fun `short pool entries are short and complete`() {
        assertTrue(widgetShortDhikrPool.isNotEmpty())
        widgetShortDhikrPool.forEach {
            // Everything in the short pool must fit two lines on a 2x2 cell
            // without truncation — that is the whole reason the pool exists.
            assertTrue(it.arabic, arabicVisualLength(it.arabic) <= 26)
            assertTrue(it.translation.isNotBlank())
            assertTrue(it.source.isNotBlank())
        }
    }

    @Test
    fun `short dhikr rotates hourly and long dua every three hours`() {
        val hour = 3_600_000L
        val base = 0L
        assertEquals(widgetShortDhikr(base), widgetShortDhikr(base + hour - 1))
        assertTrue(widgetShortDhikr(base) != widgetShortDhikr(base + hour))
        assertEquals(widgetDua(base), widgetDua(base + 3 * hour - 1))
        assertTrue(widgetDua(base) != widgetDua(base + 3 * hour))
    }

    @Test
    fun `rotation is stable for negative and large clocks`() {
        assertTrue(widgetShortDhikrPool.contains(widgetShortDhikr(-1L)))
        assertTrue(widgetDuaPool.contains(widgetDua(Long.MAX_VALUE / 2)))
    }

    @Test
    fun `arabic visual length ignores tashkeel`() {
        assertEquals("رب زدني علما".length, arabicVisualLength("رَبِّ زِدْنِي عِلْمًا"))
    }

    @Test
    fun `every short dhikr gets a large point size`() {
        widgetShortDhikrPool.forEach {
            assertTrue(it.arabic, compactDhikrFontSize(it.arabic) >= 23)
        }
    }
}
