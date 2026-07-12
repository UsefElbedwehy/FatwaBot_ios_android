package com.fatwabot.core.prayer

import kotlinx.datetime.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Mirrors iOS NotificationPlannerTests — both planners must behave identically. */
class NotificationPlannerTest {
    private val engine = PrayerEngine()

    private fun timeline(days: Int) = engine.timeline(
        24.7136, 46.6753, 2026, 3, 20, days, PrayerSettings(method = "umm_al_qura"),
    )

    @Test
    fun `adhan only when other types disabled`() {
        val plan = NotificationPlanner.plan(
            timeline(1),
            PrayerNotificationPreferences(adhanEnabled = true, preAdhanEnabled = false),
            Instant.fromEpochSeconds(0),
        )
        assertTrue(plan.all { it.kind == PlannedNotification.Kind.ADHAN })
        assertEquals(
            PrayerNameUi.entries.filter { it.isPrayer }.toSet(),
            plan.mapNotNull { it.prayer }.toSet(),
        )
    }

    @Test
    fun `adhan disabled emits nothing`() {
        val plan = NotificationPlanner.plan(
            timeline(1),
            PrayerNotificationPreferences(adhanEnabled = false, preAdhanEnabled = false),
            Instant.fromEpochSeconds(0),
        )
        assertTrue(plan.isEmpty())
    }

    @Test
    fun `pre adhan offset schedules earlier reminder`() {
        val plan = NotificationPlanner.plan(
            timeline(1),
            PrayerNotificationPreferences(adhanEnabled = true, preAdhanEnabled = true, preAdhanOffsetMinutes = 15),
            Instant.fromEpochSeconds(0),
        )
        val adhan = plan.first { it.kind == PlannedNotification.Kind.ADHAN && it.prayer == PrayerNameUi.DHUHR }
        val pre = plan.first { it.kind == PlannedNotification.Kind.PRE_ADHAN && it.prayer == PrayerNameUi.DHUHR }
        assertEquals(900L, adhan.fireEpochSeconds - pre.fireEpochSeconds)
        assertTrue(plan.indexOf(pre) < plan.indexOf(adhan))
    }

    @Test
    fun `iqama reminder fires after adhan`() {
        val days = timeline(1)
        val plan = NotificationPlanner.plan(
            days,
            PrayerNotificationPreferences(adhanEnabled = false, preAdhanEnabled = false, iqamaEnabled = true, iqamaOffsetMinutes = 20),
            Instant.fromEpochSeconds(0),
        )
        assertTrue(plan.all { it.kind == PlannedNotification.Kind.IQAMA })
        val asr = plan.first { it.prayer == PrayerNameUi.ASR }
        assertEquals(1200L, asr.fireEpochSeconds - days[0].times.getValue(PrayerNameUi.ASR).epochSeconds)
    }

    @Test
    fun `last third fires two thirds into the night`() {
        val days = timeline(2)
        val plan = NotificationPlanner.plan(
            days,
            PrayerNotificationPreferences(adhanEnabled = false, preAdhanEnabled = false, lastThirdEnabled = true),
            Instant.fromEpochSeconds(0),
        )
        assertEquals(1, plan.size)
        val n = plan[0]
        assertEquals(PlannedNotification.Kind.LAST_THIRD, n.kind)
        assertNull(n.prayer)
        val maghrib = days[0].times.getValue(PrayerNameUi.MAGHRIB).epochSeconds
        val fajrNext = days[1].times.getValue(PrayerNameUi.FAJR).epochSeconds
        val expected = maghrib + (fajrNext - maghrib) * 2L / 3L
        assertEquals(expected, n.fireEpochSeconds)
        assertTrue(n.fireEpochSeconds in (maghrib + 1) until fajrNext)
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
        val prefs = PrayerNotificationPreferences(
            adhanEnabled = true, preAdhanEnabled = true, iqamaEnabled = true, lastThirdEnabled = true,
        )
        val plan = NotificationPlanner.plan(days, prefs, now)
        assertEquals(plan.map { it.id }.size, plan.map { it.id }.toSet().size)
        assertEquals(plan, NotificationPlanner.plan(days, prefs, now))
    }
}
