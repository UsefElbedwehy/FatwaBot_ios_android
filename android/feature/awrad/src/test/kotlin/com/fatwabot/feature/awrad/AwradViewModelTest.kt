package com.fatwabot.feature.awrad

import com.fatwabot.core.content.WirdTemplate
import kotlinx.datetime.Clock
import kotlinx.datetime.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** Mirrors iOS AwradViewModelTests — both must behave identically. */
class AwradViewModelTest {
    private class InMemoryStore : WirdStoring {
        var wirds: List<Wird> = emptyList()
        var progress: List<WirdDailyProgress> = emptyList()
        var completions: List<WirdDayCompletionRecord> = emptyList()
        override fun loadWirds() = wirds
        override fun saveWirds(wirds: List<Wird>) { this.wirds = wirds }
        override fun loadProgress() = progress
        override fun saveProgress(progress: List<WirdDailyProgress>) { this.progress = progress }
        override fun loadDayCompletions() = completions
        override fun recordDayCompletion(record: WirdDayCompletionRecord) { completions = completions + record }
    }

    private val fixedNow = Instant.fromEpochSeconds(1_774_000_000)
    private val fixedClock = object : Clock {
        override fun now() = fixedNow
    }

    private fun makeViewModel(store: WirdStoring = InMemoryStore()) = AwradViewModel(null, store, fixedClock)

    private fun template(name: String = "الصلاة على النبي", type: String = "salawat", target: Int = 100, unit: String = "times") =
        WirdTemplate(id = "t1", name = name, description = "", type = type, defaultTarget = target, defaultUnit = unit, defaultFrequency = "daily")

    @Test
    fun `ticking past target does not error`() {
        val viewModel = makeViewModel()
        viewModel.createWird(template(target = 3))
        val wirdId = viewModel.state.value.wirds[0].id
        repeat(10) { viewModel.tick(wirdId) }
        assertEquals(10, viewModel.todayCount(wirdId))
    }

    @Test
    fun `day completion requires all active wirds to reach target`() {
        val viewModel = makeViewModel()
        viewModel.createWird(template(name = "A", target = 2))
        viewModel.createWird(template(name = "B", target = 2))
        val (a, b) = viewModel.state.value.wirds.map { it.id }

        viewModel.tick(a, 2)
        assertFalse("only one of two wirds met target", viewModel.markDayComplete())
        assertFalse(viewModel.isDayCompletedToday())

        viewModel.tick(b, 2)
        assertTrue(viewModel.markDayComplete())
        assertTrue(viewModel.isDayCompletedToday())
    }

    @Test
    fun `mark day complete is idempotent`() {
        val viewModel = makeViewModel()
        viewModel.createWird(template(target = 1))
        viewModel.tick(viewModel.state.value.wirds[0].id)
        assertTrue(viewModel.markDayComplete())
        assertFalse("already completed today — no duplicate record", viewModel.markDayComplete())
        assertEquals(1, viewModel.state.value.dayCompletions.size)
    }

    @Test
    fun `archiving removes from active board but keeps historical progress`() {
        val viewModel = makeViewModel()
        viewModel.createWird(template(target = 5))
        val wirdId = viewModel.state.value.wirds[0].id
        viewModel.tick(wirdId, 5)
        assertEquals(5, viewModel.state.value.stats.salawatCount)

        viewModel.archiveWird(wirdId)
        assertTrue("archived wird must not appear on the active board", viewModel.state.value.activeWirds.isEmpty())
        assertEquals("historical progress must remain in stats", 5, viewModel.state.value.stats.salawatCount)
    }

    @Test
    fun `day completion excludes archived wirds`() {
        val viewModel = makeViewModel()
        viewModel.createWird(template(name = "A", target = 1))
        viewModel.createWird(template(name = "B", target = 1))
        val (a, b) = viewModel.state.value.wirds.map { it.id }
        viewModel.archiveWird(b) // archived before ever being touched

        viewModel.tick(a, 1)
        assertTrue("archived wird B must not block completion", viewModel.markDayComplete())
    }

    @Test
    fun `stats aggregation across type and unit combinations`() {
        val viewModel = makeViewModel()
        viewModel.createWird(template(name = "Salawat", type = "salawat", target = 100, unit = "times"))
        viewModel.createWird(template(name = "Quran", type = "quran_reading", target = 5, unit = "pages"))
        viewModel.createWird(template(name = "Istighfar", type = "istighfar", target = 100, unit = "times"))
        val (salawat, quran, istighfar) = viewModel.state.value.wirds.map { it.id }

        viewModel.tick(salawat, 30)
        viewModel.tick(quran, 3)
        viewModel.tick(istighfar, 20)

        val stats = viewModel.state.value.stats
        assertEquals("only page-unit wirds count toward Qur'an pages", 3, stats.quranPagesCount)
        assertEquals("only salawat-type wirds count toward salawat", 30, stats.salawatCount)
        assertEquals(
            "non-page wirds (salawat + istighfar) sum into the general dhikr total",
            50,
            stats.totalDhikrCount,
        )
    }

    @Test
    fun `template list renders offline from bundled seed`() {
        // No live ContentService injected — mirrors "renders even fully offline
        // on first launch" via the bundled seed fallback ContentKit provides.
        val viewModel = makeViewModel()
        viewModel.loadTemplates("ar")
        assertTrue(
            "without a ContentService, templates stay empty rather than crashing",
            viewModel.state.value.templates.isEmpty(),
        )
    }

    @Test
    fun `custom wird creation clamps target to at least one`() {
        val viewModel = makeViewModel()
        viewModel.createCustomWird(name = "ورد خاص", type = "custom", target = 0, unit = "times", frequency = "daily")
        assertEquals(1, viewModel.state.value.wirds.first().target)
    }
}
