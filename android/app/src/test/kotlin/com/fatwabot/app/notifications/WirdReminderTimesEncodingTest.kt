package com.fatwabot.app.notifications

import com.fatwabot.feature.awrad.WirdReminderTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The "wirdId=HH:mm;…" encoding used to squeeze a map into SharedPreferences.
 * Parsing is the risky half — a bad entry must cost that one override, never
 * the user's whole reminder schedule.
 */
class WirdReminderTimesEncodingTest {
    @Test
    fun `round trips a map`() {
        val times = mapOf(
            "fixed-qiyam-al-layl" to WirdReminderTime(3, 5),
            "fixed-morning-azkar" to WirdReminderTime(6, 45),
        )
        assertEquals(times, decodeWirdTimes(encodeWirdTimes(times)))
    }

    @Test
    fun `encoding is stable across saves`() {
        val times = mapOf("b" to WirdReminderTime(1, 0), "a" to WirdReminderTime(2, 0))
        // An unordered map would rewrite the same data differently every save.
        assertEquals(encodeWirdTimes(times), encodeWirdTimes(times.toList().reversed().toMap()))
    }

    @Test
    fun `a corrupt entry costs only itself`() {
        val raw = "fixed-qiyam-al-layl=03:05;garbage;=04:00;fixed-morning-azkar=6:45;x=zz:zz"
        val decoded = decodeWirdTimes(raw)
        assertEquals(WirdReminderTime(3, 5), decoded["fixed-qiyam-al-layl"])
        assertEquals(WirdReminderTime(6, 45), decoded["fixed-morning-azkar"])
        assertEquals(2, decoded.size)
    }

    @Test
    fun `blank and null decode to no overrides`() {
        assertTrue(decodeWirdTimes(null).isEmpty())
        assertTrue(decodeWirdTimes("").isEmpty())
    }

    @Test
    fun `out of range stored values are clamped on read`() {
        assertEquals(WirdReminderTime(23, 59), decodeWirdTimes("a=99:99")["a"])
    }
}
