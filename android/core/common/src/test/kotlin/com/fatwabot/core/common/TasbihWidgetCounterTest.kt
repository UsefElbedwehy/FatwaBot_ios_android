package com.fatwabot.core.common

import java.io.File
import java.nio.file.Files
import java.time.LocalDate
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test

/** Mirrors iOS TasbihWidgetCounterTests. */
class TasbihWidgetCounterTest {
    private lateinit var dir: File

    @Before fun setUp() { dir = Files.createTempDirectory("tasbih").toFile() }
    @After fun tearDown() { dir.deleteRecursively() }

    private val today: LocalDate = LocalDate.of(2026, 8, 8)
    private val yesterday: LocalDate = today.minusDays(1)

    @Test
    fun `increment raises the tally`() {
        var counter = TasbihWidgetCounter(day = today.toString())
        counter = counter.incremented(today)
        counter = counter.incremented(today)
        assertEquals(2, counter.current(today))
    }

    @Test
    fun `a tally from an earlier day reads as zero`() {
        val stale = TasbihWidgetCounter(count = 100, day = yesterday.toString())
        // Without this, someone who counted 100 last night opens their phone to
        // a widget claiming 100 today.
        assertEquals(0, stale.current(today))
    }

    @Test
    fun `incrementing a stale tally starts from zero not from yesterday`() {
        val stale = TasbihWidgetCounter(count = 100, day = yesterday.toString())
        // The first tap of a new day must read 1, not 101.
        assertEquals(1, stale.incremented(today).current(today))
    }

    @Test
    fun `reset zeroes and claims today`() {
        val counter = TasbihWidgetCounter(count = 33, day = yesterday.toString()).reset(today)
        assertEquals(0, counter.current(today))
        assertEquals(today.toString(), counter.day)
    }

    @Test
    fun `store round trips`() {
        val store = TasbihWidgetCounter.store(dir)
        store.write(TasbihWidgetCounter(day = today.toString()).incremented(today).incremented(today))
        assertEquals(2, store.read().current(today))
    }

    @Test
    fun `reading before anything was written is zero not a failure`() {
        // Every install takes this path once; it must not throw or show a
        // placeholder where a number belongs.
        assertEquals(0, TasbihWidgetCounter.store(dir).read().current(today))
    }

    @Test
    fun `a corrupt counter file reads as zero rather than crashing the widget`() {
        File(dir, "tasbih-widget-counter.json").writeText("not json")
        assertEquals(0, TasbihWidgetCounter.store(dir).read().current(today))
    }
}
