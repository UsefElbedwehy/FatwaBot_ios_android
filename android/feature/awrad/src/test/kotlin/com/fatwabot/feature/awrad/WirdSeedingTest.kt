package com.fatwabot.feature.awrad

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * [FixedWirdSlots.applied] — the pure seeding rule behind "أضف ورد اليوم"
 * (client decision, 2026-08-12: nothing is seeded automatically anymore; a
 * user opts in with one tap, and the four fixed slots are ordinary wirds
 * after that — tickable, retargetable, deletable). Mirror of iOS
 * WirdSeedingTests.
 */
class WirdSeedingTest {
    private val now = 1_800_000_000L

    private fun custom(id: String, archivedAtEpochSeconds: Long? = null) = Wird(
        id = id, name = "ورد مخصص", type = "custom", target = 3, unit = "times",
        frequency = "daily", createdAtEpochSeconds = 0, archivedAtEpochSeconds = archivedAtEpochSeconds,
    )

    @Test
    fun `applied to an empty board adds all four slots`() {
        val result = FixedWirdSlots.applied(emptyList(), nowEpochSeconds = now)

        assertEquals(FixedWirdSlot.entries.size, result.size)
        assertTrue(result.all { it.isFixed })
        assertTrue(result.all { it.isActive })
    }

    @Test
    fun `applied preserves existing custom wirds`() {
        val result = FixedWirdSlots.applied(listOf(custom("mine-1")), nowEpochSeconds = now)

        assertTrue(result.any { it.id == "mine-1" })
        assertEquals(FixedWirdSlot.entries.size + 1, result.size)
    }

    @Test
    fun `applied is idempotent`() {
        val once = FixedWirdSlots.applied(listOf(custom("mine-1")), nowEpochSeconds = now)
        val twice = FixedWirdSlots.applied(once, nowEpochSeconds = now)

        assertEquals(once, twice)
    }

    @Test
    fun `applied does not duplicate an already present slot`() {
        val existing = listOf(FixedWirdSlots.wird(FixedWirdSlot.QIYAM_AL_LAYL, nowEpochSeconds = now))
        val result = FixedWirdSlots.applied(existing, nowEpochSeconds = now)

        assertEquals(1, result.count { it.id == FixedWirdSlot.QIYAM_AL_LAYL.wirdId })
        assertEquals(FixedWirdSlot.entries.size, result.size)
    }

    /** A fixed slot the user deleted, then asked to add back — re-adding
     * restores the *same* record (id, createdAt) rather than starting a
     * duplicate, so its history stays attached. */
    @Test
    fun `applied reactivates a deleted fixed slot`() {
        val deleted = FixedWirdSlots.wird(FixedWirdSlot.QIYAM_AL_LAYL, nowEpochSeconds = 0)
            .copy(archivedAtEpochSeconds = 100)

        val result = FixedWirdSlots.applied(listOf(deleted), nowEpochSeconds = now)

        val qiyam = result.firstOrNull { it.id == FixedWirdSlot.QIYAM_AL_LAYL.wirdId }
        assertNotNull(qiyam)
        assertTrue(qiyam!!.isActive)
        assertEquals(0L, qiyam.createdAtEpochSeconds)
    }

    /** A deleted *custom* wird is left alone — "أضف ورد اليوم" only concerns
     * the four fixed slots. */
    @Test
    fun `applied does not reactivate a deleted custom wird`() {
        val deletedCustom = custom("mine-1", archivedAtEpochSeconds = 100)
        val result = FixedWirdSlots.applied(listOf(deletedCustom), nowEpochSeconds = now)

        assertFalse(result.first { it.id == "mine-1" }.isActive)
    }

    // Client report: fixed-slot names stuck in the wrong language after a
    // locale switch.

    @Test
    fun `normalized refreshes a fixed slot name to the current resolver`() {
        val staleEnglish = FixedWirdSlots.wird(
            FixedWirdSlot.QIYAM_AL_LAYL,
            name = FixedWirdSlots.NameResolver { "Night Prayer (Qiyam)" },
            nowEpochSeconds = now,
        )

        val result = FixedWirdSlots.normalized(listOf(staleEnglish), FixedWirdSlots.NameResolver { "قيام الليل" })

        assertEquals("قيام الليل", result.first().name)
    }

    @Test
    fun `normalized leaves custom wird names alone`() {
        val result = FixedWirdSlots.normalized(listOf(custom("mine-1")), FixedWirdSlots.NameResolver { "قيام الليل" })

        assertEquals("ورد مخصص", result.first().name)
    }

    @Test
    fun `normalized does not add or reactivate anything`() {
        val result = FixedWirdSlots.normalized(listOf(custom("mine-1")), FixedWirdSlots.NameResolver { "قيام الليل" })

        assertEquals(1, result.size)
    }
}
