package com.fatwabot.feature.awrad

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Mirrors `FixedWirdSlotsTests` on iOS. The two suites assert the same rules on
 * purpose — the slot ids are a cross-platform contract, so a divergence here is
 * a user whose board differs depending on which phone they installed on.
 */
class FixedWirdSlotsTest {

    private val now = 1_700_000_000L

    @Test
    fun `ids match the cross-platform contract`() {
        assertEquals(
            listOf(
                "fixed-qiyam-al-layl",
                "fixed-daily-quran",
                "fixed-morning-azkar",
                "fixed-evening-azkar",
            ),
            FixedWirdSlot.entries.map { it.wirdId },
        )
    }

    @Test
    fun `seeds all four onto an empty board`() {
        val seeded = FixedWirdSlots.applied(emptyList(), nowEpochSeconds = now)
        assertEquals(4, seeded.size)
        assertTrue(seeded.all { it.isFixed })
        assertEquals(FixedWirdSlot.entries.map { it.wirdId }, seeded.map { it.id })
    }

    @Test
    fun `is idempotent and never resets a retargeted slot`() {
        val once = FixedWirdSlots.applied(emptyList(), nowEpochSeconds = now)
        val retargeted = once.map { if (it.id == "fixed-daily-quran") it.copy(target = 20) else it }
        val twice = FixedWirdSlots.applied(retargeted, nowEpochSeconds = now)
        assertEquals(retargeted, twice)
        assertEquals(20, twice.first { it.id == "fixed-daily-quran" }.target)
    }

    @Test
    fun `keeps user wirds and appends only the missing slots`() {
        val mine = Wird(
            id = "mine",
            name = "ورد خاص",
            type = "custom",
            target = 3,
            unit = "times",
            frequency = "daily",
            createdAtEpochSeconds = now,
        )
        val partial = listOf(mine, FixedWirdSlots.wird(FixedWirdSlot.MORNING_AZKAR, nowEpochSeconds = now))
        val seeded = FixedWirdSlots.applied(partial, nowEpochSeconds = now)
        assertEquals(5, seeded.size)
        assertEquals(mine, seeded.first())
        assertEquals(1, seeded.count { it.id == FixedWirdSlot.MORNING_AZKAR.wirdId })
    }

    @Test
    fun `repairs a record written before isFixed existed`() {
        // Decodes with isFixed = false; the id is what identifies it.
        val legacy = Wird(
            id = FixedWirdSlot.QIYAM_AL_LAYL.wirdId,
            name = "قيام الليل",
            type = "qiyam",
            target = 2,
            unit = "rakaat",
            frequency = "daily",
            createdAtEpochSeconds = now,
            archivedAtEpochSeconds = now,
            isFixed = false,
        )
        val repaired = FixedWirdSlots.applied(listOf(legacy), nowEpochSeconds = now)
            .first { it.id == FixedWirdSlot.QIYAM_AL_LAYL.wirdId }
        assertTrue(repaired.isFixed)
        assertNull(repaired.archivedAtEpochSeconds)
    }

    @Test
    fun `reminders put user wirds ahead of fixed slots and honour slot hours`() {
        val mine = Wird(
            id = "mine",
            name = "ورد",
            type = "custom",
            target = 1,
            unit = "times",
            frequency = "daily",
            createdAtEpochSeconds = now,
        )
        val board = FixedWirdSlots.applied(listOf(mine), nowEpochSeconds = now)
        val plan = WirdReminderPlanner.plan(board, WirdReminderPreferences(hour = 20, minute = 30))

        assertEquals("mine", plan.first().wirdId)
        assertEquals(20, plan.first().hour)
        assertEquals(30, plan.first().minute)

        val qiyam = plan.first { it.wirdId == FixedWirdSlot.QIYAM_AL_LAYL.wirdId }
        assertEquals(22, qiyam.hour)
        assertEquals(0, qiyam.minute)

        // No slot hour → falls back to the user's configured time.
        val quran = plan.first { it.wirdId == FixedWirdSlot.DAILY_QURAN.wirdId }
        assertEquals(20, quran.hour)
        assertEquals(30, quran.minute)

        // Fixed slots keep their canonical board order behind the user's wirds.
        assertEquals(
            FixedWirdSlot.entries.map { it.wirdId },
            plan.drop(1).map { it.wirdId },
        )
    }

    @Test
    fun `budget truncation evicts fixed slots before user wirds`() {
        val mine = (1..5).map {
            Wird(
                id = "mine-$it",
                name = "ورد $it",
                type = "custom",
                target = 1,
                unit = "times",
                frequency = "daily",
                createdAtEpochSeconds = now + it,
            )
        }
        val board = FixedWirdSlots.applied(mine, nowEpochSeconds = now)
        val plan = WirdReminderPlanner.plan(board, WirdReminderPreferences())
        assertEquals(WirdReminderPlanner.NOTIFICATION_RESERVE, plan.size)
        assertTrue(plan.none { FixedWirdSlots.isFixed(it.wirdId) })
    }
}
