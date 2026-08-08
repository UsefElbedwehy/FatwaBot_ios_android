package com.fatwabot.feature.awrad

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** Mirrors iOS WirdReminderTimeTests — per-wird reminder times. */
class WirdReminderTimeTest {
    @Test
    fun `an override wins over everything`() {
        val prefs = WirdReminderPreferences(hour = 20, minute = 0)
            .withTime("fixed-morning-azkar", WirdReminderTime.of(5, 30))
        // The user chose 05:30; the slot's built-in 08:00 must not override it.
        assertEquals(WirdReminderTime(5, 30), prefs.timeFor("fixed-morning-azkar", 8))
    }

    @Test
    fun `without an override the slot default is used`() {
        val prefs = WirdReminderPreferences(hour = 20, minute = 0)
        assertEquals(WirdReminderTime(8, 0), prefs.timeFor("fixed-morning-azkar", 8))
    }

    @Test
    fun `a user created wird falls back to the global time`() {
        val prefs = WirdReminderPreferences(hour = 21, minute = 15)
        assertEquals(WirdReminderTime(21, 15), prefs.timeFor("my-own-wird", null))
    }

    @Test
    fun `overrides are independent per wird`() {
        val prefs = WirdReminderPreferences()
            .withTime("fixed-qiyam-al-layl", WirdReminderTime.of(3, 0))
            .withTime("fixed-morning-azkar", WirdReminderTime.of(6, 45))
        assertEquals(3, prefs.timeFor("fixed-qiyam-al-layl", 22).hour)
        assertEquals(45, prefs.timeFor("fixed-morning-azkar", 8).minute)
        // An untouched wird is unaffected by the others' overrides.
        assertEquals(17, prefs.timeFor("fixed-evening-azkar", 17).hour)
    }

    @Test
    fun `out of range times are clamped`() {
        val time = WirdReminderTime.of(99, -5)
        assertEquals(23, time.hour)
        assertEquals(0, time.minute)
    }
}
