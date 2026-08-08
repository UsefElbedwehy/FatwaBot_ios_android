package com.fatwabot.core.prayer

import java.time.LocalDate
import java.time.ZoneId
import kotlinx.datetime.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** Mirrors iOS NotificationBudgetTests. */
class NotificationBudgetTest {
    private val engine = PrayerEngine()

    private fun timeline(days: Int) =
        engine.timeline(24.7136, 46.6753, 2026, 3, 20, days, PrayerSettings(method = "umm_al_qura"))

    /** Everything on: 5 adhan + 5 pre-adhan + 5 iqama + 1 last third per day. */
    private val full = PrayerNotificationPreferences(
        adhanEnabled = true, preAdhanEnabled = true, preAdhanOffsetMinutes = 10,
        iqamaEnabled = true, lastThirdEnabled = true,
    )

    private fun before(days: List<PrayerDayUi>) =
        Instant.fromEpochSeconds(days.first().times.getValue(PrayerNameUi.FAJR).epochSeconds - 3600)

    private fun dayOf(epochSeconds: Long): LocalDate =
        java.time.Instant.ofEpochSecond(epochSeconds).atZone(ZoneId.systemDefault()).toLocalDate()

    @Test
    fun `adhan survives across the whole horizon when the budget is tight`() {
        val days = timeline(10)
        val plan = NotificationPlanner.plan(days, full, before(days), budget = 48)
        // The bug: chronological truncation gave three days of everything and
        // then silence — no adhan at all from day four.
        val adhanDays = plan
            .filter { it.kind == PlannedNotification.Kind.ADHAN }
            .map { dayOf(it.fireEpochSeconds) }
            .toSet()
        assertTrue("adhan must cover most of the horizon, got ${adhanDays.size}", adhanDays.size >= 8)
        assertTrue(plan.size <= 48)
    }

    @Test
    fun `adhan is never dropped in favour of a softer reminder`() {
        val days = timeline(10)
        val all = NotificationPlanner.plan(days, full, before(days), budget = 10_000)
        val capped = NotificationPlanner.plan(days, full, before(days), budget = 48)
        val allAdhan = all.count { it.kind == PlannedNotification.Kind.ADHAN }
        val keptAdhan = capped.count { it.kind == PlannedNotification.Kind.ADHAN }
        assertEquals(minOf(allAdhan, 48), keptAdhan)
    }

    @Test
    fun `the plan is still chronological after allocation`() {
        val days = timeline(10)
        val plan = NotificationPlanner.plan(days, full, before(days), budget = 48)
        assertEquals(plan.map { it.fireEpochSeconds }.sorted(), plan.map { it.fireEpochSeconds })
    }

    @Test
    fun `a plan that fits is left completely alone`() {
        val days = timeline(2)
        val plan = NotificationPlanner.plan(days, full, before(days), budget = 10_000)
        // Under budget, every reminder the user asked for must be present —
        // prioritisation must not quietly drop things when there is room.
        assertTrue(plan.any { it.kind == PlannedNotification.Kind.IQAMA })
        assertTrue(plan.any { it.kind == PlannedNotification.Kind.LAST_THIRD })
        assertTrue(plan.any { it.kind == PlannedNotification.Kind.PRE_ADHAN })
    }
}
