package com.fatwabot.feature.awrad

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** Mirrors iOS WirdReminderPlannerTests — both must behave identically. */
class WirdReminderPlannerTest {

    private fun wird(id: String, archived: Boolean = false, createdOffset: Long = 0) = Wird(
        id = id,
        name = "ورد",
        type = "dhikr",
        target = 33,
        unit = "times",
        frequency = "daily",
        createdAtEpochSeconds = 1_770_000_000 + createdOffset,
        archivedAtEpochSeconds = if (archived) 1_773_000_000 else null,
    )

    @Test
    fun `one reminder per active wird`() {
        val plan = WirdReminderPlanner.plan(
            listOf(wird("a"), wird("b", createdOffset = 10)),
            WirdReminderPreferences(),
        )

        assertEquals(listOf("a", "b"), plan.map { it.wirdId })
        assertEquals(listOf("wird-reminder-a", "wird-reminder-b"), plan.map { it.id })
        assertEquals(setOf(20), plan.map { it.hour }.toSet())
        assertEquals(setOf(0), plan.map { it.minute }.toSet())
    }

    @Test
    fun `archived wirds get no reminder`() {
        val plan = WirdReminderPlanner.plan(
            listOf(wird("a"), wird("old", archived = true, createdOffset = 5)),
            WirdReminderPreferences(),
        )
        assertEquals(listOf("a"), plan.map { it.wirdId })
    }

    @Test
    fun `no awrad yields no reminders`() {
        assertTrue(WirdReminderPlanner.plan(emptyList(), WirdReminderPreferences()).isEmpty())
    }

    @Test
    fun `only archived awrad yields no reminders`() {
        val plan = WirdReminderPlanner.plan(listOf(wird("old", archived = true)), WirdReminderPreferences())
        assertTrue(plan.isEmpty())
    }

    @Test
    fun `toggle off yields no reminders`() {
        val plan = WirdReminderPlanner.plan(
            listOf(wird("a"), wird("b", createdOffset = 1)),
            WirdReminderPreferences(enabled = false),
        )
        assertTrue(plan.isEmpty())
    }

    @Test
    fun `chosen time is carried onto every reminder`() {
        val plan = WirdReminderPlanner.plan(
            listOf(wird("a"), wird("b", createdOffset = 1)),
            WirdReminderPreferences(hour = 6, minute = 45),
        )
        assertEquals(listOf(6, 6), plan.map { it.hour })
        assertEquals(listOf(45, 45), plan.map { it.minute })
    }

    @Test
    fun `budget caps the number of reminders deterministically`() {
        val wirds = (0..9).map { wird("w$it", createdOffset = it.toLong()) }

        val plan = WirdReminderPlanner.plan(wirds, WirdReminderPreferences(), budget = 3)
        assertEquals(listOf("w0", "w1", "w2"), plan.map { it.wirdId })

        val again = WirdReminderPlanner.plan(wirds.reversed(), WirdReminderPreferences(), budget = 3)
        assertEquals(plan.map { it.wirdId }, again.map { it.wirdId })
    }

    @Test
    fun `zero budget yields no reminders`() {
        assertTrue(WirdReminderPlanner.plan(listOf(wird("a")), WirdReminderPreferences(), budget = 0).isEmpty())
    }

    @Test
    fun `out of range times are clamped`() {
        val plan = WirdReminderPlanner.plan(
            listOf(wird("a")),
            WirdReminderPreferences(hour = 99, minute = -5),
        )
        assertEquals(23, plan[0].hour)
        assertEquals(0, plan[0].minute)
    }

    @Test
    fun `budget after reserve never goes negative`() {
        assertEquals(16 - WirdReminderPlanner.NOTIFICATION_RESERVE, WirdReminderPlanner.budgetAfterReserve(16))
        assertEquals(0, WirdReminderPlanner.budgetAfterReserve(1))
    }
}
