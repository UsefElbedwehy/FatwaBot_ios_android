package com.fatwabot.feature.awrad

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** Mirrors iOS FixedOnlyBoardTests. */
class FixedOnlyBoardTest {

    private class InMemoryWirdStore : WirdStoring {
        var wirds: List<Wird> = emptyList()
        override fun loadWirds(): List<Wird> = wirds
        override fun saveWirds(wirds: List<Wird>) { this.wirds = wirds }
        override fun loadProgress(): List<WirdDailyProgress> = emptyList()
        override fun saveProgress(progress: List<WirdDailyProgress>) = Unit
        override fun loadDayCompletions(): List<WirdDayCompletionRecord> = emptyList()
        override fun recordDayCompletion(record: WirdDayCompletionRecord) = Unit
    }

    private fun custom(id: String) = Wird(
        id = id, name = "ورد مخصص", type = "custom", target = 3, unit = "times",
        frequency = "daily", createdAtEpochSeconds = 0,
    )

    private fun store(base: InMemoryWirdStore) =
        SeededWirdStore(base, { slot -> slot.defaultName }, { 1_800_000_000L })

    @Test
    fun `the board returns only the four fixed slots`() {
        val base = InMemoryWirdStore()
        base.wirds = listOf(custom("mine-1"), custom("mine-2"))
        val loaded = store(base).loadWirds()

        assertEquals(FixedWirdSlot.entries.size, loaded.size)
        assertTrue(loaded.all { it.isFixed })
        assertFalse(loaded.any { it.id == "mine-1" })
    }

    @Test
    fun `saving the filtered board does not erase user wirds from disk`() {
        // The dangerous path: load (four slots), tick a counter, save. A
        // replacing write would drop the user's own wirds permanently — hidden
        // becoming destroyed on the first tap, with nothing to undo it.
        val base = InMemoryWirdStore()
        base.wirds = listOf(custom("mine-1"))
        val seeded = store(base)

        seeded.saveWirds(seeded.loadWirds())

        assertTrue(
            "a user's own wird must survive a save of the filtered board",
            base.wirds.any { it.id == "mine-1" },
        )
    }

    @Test
    fun `the four slots are still seeded onto an empty board`() {
        assertEquals(FixedWirdSlot.entries.size, store(InMemoryWirdStore()).loadWirds().size)
    }
}
