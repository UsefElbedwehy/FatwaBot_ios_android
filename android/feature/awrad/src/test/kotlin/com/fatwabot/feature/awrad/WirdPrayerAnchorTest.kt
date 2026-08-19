package com.fatwabot.feature.awrad

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Mirrors iOS WirdPrayerAnchorTests. */
class WirdPrayerAnchorTest {
    private val morningId = "fixed-morning-azkar"
    private val fajrMillis = 1_800_000_000_000L

    private fun wird(id: String) = Wird(
        id = id, name = "أذكار الصباح", type = "azkar", target = 1, unit = "times",
        frequency = "daily", createdAtEpochSeconds = 0, isFixed = true,
    )

    private fun fajrLookup() = WirdReminderPlanner.PrayerTimeLookup { offset, prayer ->
        if (prayer != "fajr") null else fajrMillis + offset * 86_400_000L
    }

    @Test
    fun `anchored wird fires relative to the prayer not the clock`() {
        val prefs = WirdReminderPreferences(hour = 20, minute = 0)
            .withPrayerAnchor(morningId, WirdPrayerAnchor("fajr", 30))
        val plan = WirdReminderPlanner.plan(
            listOf(wird(morningId)), prefs, budget = 5,
            nowMillis = fajrMillis - 3_600_000, prayerTime = fajrLookup(),
        )
        assertTrue(plan.isNotEmpty())
        val trigger = plan[0].trigger
        assertTrue("anchored wirds must be dated one-shots", trigger is PlannedWirdReminder.Trigger.OneShot)
        // 30 minutes after Fajr, not the 20:00 sitting in preferences.
        assertEquals(fajrMillis + 1_800_000, (trigger as PlannedWirdReminder.Trigger.OneShot).epochMillis)
    }

    @Test
    fun `anchored wird emits one reminder per day of horizon`() {
        val prefs = WirdReminderPreferences()
            .withPrayerAnchor(morningId, WirdPrayerAnchor("fajr", 0))
        val plan = WirdReminderPlanner.plan(
            listOf(wird(morningId)), prefs, budget = 5,
            nowMillis = fajrMillis - 60_000, prayerTime = fajrLookup(),
        )
        assertEquals(WirdReminderPlanner.PRAYER_ANCHOR_HORIZON_DAYS, plan.size)
    }

    @Test
    fun `a prayer already past today is skipped`() {
        val prefs = WirdReminderPreferences()
            .withPrayerAnchor(morningId, WirdPrayerAnchor("fajr", 0))
        // Opened the app after Fajr — today's is gone, tomorrow's is not.
        val plan = WirdReminderPlanner.plan(
            listOf(wird(morningId)), prefs, budget = 5,
            nowMillis = fajrMillis + 3_600_000, prayerTime = fajrLookup(),
        )
        assertEquals(WirdReminderPlanner.PRAYER_ANCHOR_HORIZON_DAYS - 1, plan.size)
    }

    @Test
    fun `without prayer times an anchored wird falls back to its clock time`() {
        val prefs = WirdReminderPreferences(hour = 21, minute = 15)
            .withPrayerAnchor(morningId, WirdPrayerAnchor("fajr", 0))
        val plan = WirdReminderPlanner.plan(listOf(wird(morningId)), prefs, budget = 5)
        assertEquals(1, plan.size)
        assertEquals(PlannedWirdReminder.Trigger.DailyAt, plan[0].trigger)
        // The slot default, exactly as before anchoring existed.
        assertEquals(8, plan[0].hour)
    }

    @Test
    fun `clearing the anchor restores the chosen clock time`() {
        val prefs = WirdReminderPreferences()
            .withTime(morningId, WirdReminderTime.of(6, 30))
            .withPrayerAnchor(morningId, WirdPrayerAnchor("fajr", 0))
            .withoutPrayerAnchor(morningId)
        assertNull(prefs.prayerAnchor(morningId))
        assertEquals(WirdReminderTime(6, 30), prefs.timeFor(morningId, 8))
    }

    @Test
    fun `the budget counts reminders not wirds`() {
        val prefs = WirdReminderPreferences()
            .withPrayerAnchor(morningId, WirdPrayerAnchor("fajr", 0))
        val plan = WirdReminderPlanner.plan(
            listOf(wird(morningId)), prefs, budget = 2,
            nowMillis = fajrMillis - 60_000, prayerTime = fajrLookup(),
        )
        // Counting wirds would let one anchored wird emit three alarms against a
        // budget of two and overshoot the reserve.
        assertEquals(2, plan.size)
    }
}
