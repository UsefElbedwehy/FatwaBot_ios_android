package com.fatwabot.core.prayer

import kotlinx.datetime.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** Mirrors iOS NotificationPlannerTests — both planners must behave identically. */
class NotificationPlannerTest {
    private val engine = PrayerEngine()

    private fun timeline(days: Int) = engine.timeline(
        24.7136, 46.6753, 2026, 3, 20, days, PrayerSettings(method = "umm_al_qura"),
    )

    @Test
    fun `plans adhan for enabled prayers only`() {
        val plan = NotificationPlanner.plan(
            timeline(1),
            PrayerNotificationPreferences(adhanEnabled = setOf(PrayerNameUi.FAJR, PrayerNameUi.MAGHRIB)),
            Instant.fromEpochSeconds(0),
        )
        assertEquals(setOf(PrayerNameUi.FAJR, PrayerNameUi.MAGHRIB), plan.map { it.prayer }.toSet())
        assertTrue(plan.all { it.kind == PlannedNotification.Kind.ADHAN })
    }

    @Test
    fun `pre adhan offset schedules earlier reminder`() {
        val plan = NotificationPlanner.plan(
            timeline(1),
            PrayerNotificationPreferences(
                adhanEnabled = setOf(PrayerNameUi.DHUHR),
                preAdhanOffsetMinutes = mapOf(PrayerNameUi.DHUHR to 15),
            ),
            Instant.fromEpochSeconds(0),
        )
        val adhan = plan.first { it.kind == PlannedNotification.Kind.ADHAN }
        val pre = plan.first { it.kind == PlannedNotification.Kind.PRE_ADHAN }
        assertEquals(900L, adhan.fireEpochSeconds - pre.fireEpochSeconds)
        assertTrue(plan.indexOf(pre) < plan.indexOf(adhan))
    }

    @Test
    fun `past fire dates are dropped`() {
        val days = timeline(1)
        val now = Instant.fromEpochSeconds(days[0].times.getValue(PrayerNameUi.DHUHR).epochSeconds + 60)
        val plan = NotificationPlanner.plan(days, PrayerNotificationPreferences(), now)
        assertFalse(plan.any { it.prayer == PrayerNameUi.FAJR })
        assertTrue(plan.any { it.prayer == PrayerNameUi.ASR })
        assertTrue(plan.all { it.fireEpochSeconds > now.epochSeconds })
    }

    @Test
    fun `budget cap keeps earliest`() {
        val plan = NotificationPlanner.plan(
            timeline(5), PrayerNotificationPreferences(), Instant.fromEpochSeconds(0), budget = 7,
        )
        assertEquals(7, plan.size)
        assertEquals(plan.sortedBy { it.fireEpochSeconds }, plan)
    }

    @Test
    fun `ids are stable and unique`() {
        val days = timeline(3)
        val now = Instant.fromEpochSeconds(0)
        val plan = NotificationPlanner.plan(days, PrayerNotificationPreferences(), now)
        assertEquals(plan.map { it.id }.size, plan.map { it.id }.toSet().size)
        assertEquals(plan, NotificationPlanner.plan(days, PrayerNotificationPreferences(), now))
    }
}
