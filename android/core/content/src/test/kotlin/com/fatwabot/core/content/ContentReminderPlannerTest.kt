package com.fatwabot.core.content

import com.fatwabot.core.common.DeepLink
import kotlinx.datetime.Instant
import kotlinx.datetime.LocalDate
import kotlinx.datetime.LocalDateTime
import kotlinx.datetime.TimeZone
import kotlinx.datetime.toInstant
import kotlinx.datetime.toLocalDateTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Mirrors iOS ContentReminderPlannerTests — both planners must behave identically. */
class ContentReminderPlannerTest {
    /** Fixed zone so the waking-window assertions don't depend on the CI machine. */
    private val zone = TimeZone.of("Asia/Riyadh")

    private fun at(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0): Instant =
        LocalDateTime(year, month, day, hour, minute).toInstant(zone)

    private fun pool(prefix: String, count: Int, wordCount: Int = 4): List<ContentSnippet> =
        (0 until count).map { index ->
            ContentSnippet(
                id = "$prefix-$index",
                text = List(wordCount) { "$prefix$index" }.joinToString(" "),
            )
        }

    private fun plan(
        perDay: Int = 2,
        enabled: Boolean = true,
        azkar: List<ContentSnippet> = pool("zikr", 12),
        hadith: List<ContentSnippet> = pool("hadith", 9),
        now: Instant = at(2026, 7, 28, 0, 30),
        horizonDays: Int = ContentReminderPlanner.DEFAULT_HORIZON_DAYS,
        budget: Int = ContentReminderPlanner.DEFAULT_BUDGET,
    ): List<PlannedContentReminder> = ContentReminderPlanner.plan(
        azkar = azkar,
        hadith = hadith,
        preferences = ContentReminderPreferences(enabled = enabled, perDay = perDay),
        now = now,
        timeZone = zone,
        horizonDays = horizonDays,
        budget = budget,
    )

    private fun PlannedContentReminder.localTime(): LocalDateTime =
        Instant.fromEpochSeconds(fireEpochSeconds).toLocalDateTime(zone)

    private fun PlannedContentReminder.localDate(): LocalDate = localTime().date

    // region Determinism

    /**
     * The whole reason the RNG is seeded: re-planning happens on every launch and
     * every settings change, and it must be a no-op, not a reshuffle.
     */
    @Test
    fun `repeated planning of the same day is identical`() {
        val first = plan()
        val second = plan()
        assertTrue(first.isNotEmpty())
        assertEquals(first, second)
    }

    /**
     * Planning later the same day must not move the reminders that are still
     * ahead — it may only drop the ones that have already fired. Horizon and
     * budget are set so the budget doesn't bind: at the cap, dropping elapsed
     * reminders legitimately pulls in later days that weren't in the first plan.
     */
    @Test
    fun `later replan keeps the surviving reminders unmoved`() {
        val morning = plan(perDay = 5, now = at(2026, 7, 28, 0, 30), horizonDays = 2, budget = 64)
        val afternoon = plan(perDay = 5, now = at(2026, 7, 28, 15, 0), horizonDays = 2, budget = 64)
        assertTrue(afternoon.size < morning.size)
        val byId = morning.associateBy { it.id }
        afternoon.forEach { item ->
            assertNotNull(byId[item.id])
            assertEquals(byId[item.id]?.fireEpochSeconds, item.fireEpochSeconds)
            assertEquals(byId[item.id]?.contentId, item.contentId)
        }
    }

    @Test
    fun `different days get different times`() {
        val all = plan(perDay = 1, horizonDays = 7, budget = 16)
        val minutes = all.map { it.localTime().hour * 60 + it.localTime().minute }.toSet()
        assertTrue(minutes.size > 1)
    }

    // endregion

    // region Count

    @Test
    fun `zero per day emits nothing`() {
        assertTrue(plan(perDay = 0).isEmpty())
    }

    @Test
    fun `disabled toggle emits nothing even with a non zero count`() {
        assertTrue(plan(perDay = 5, enabled = false).isEmpty())
    }

    @Test
    fun `five per day emits five per day`() {
        val all = plan(perDay = 5, horizonDays = 3, budget = 100)
        val firstDay = all.filter { it.localDate() == LocalDate(2026, 7, 28) }
        assertEquals(5, firstDay.size)
        assertEquals(15, all.size)
    }

    @Test
    fun `count is clamped to the allowed range`() {
        assertEquals(5, ContentReminderPreferences(perDay = 99).effectiveCount)
        assertEquals(0, ContentReminderPreferences(perDay = -3).effectiveCount)
    }

    /** The advertised default: two a day, one azkar and one hadith. */
    @Test
    fun `default is one azkar and one hadith per day`() {
        val all = plan(horizonDays = 3, budget = 100)
        val firstDay = all.filter { it.localDate() == LocalDate(2026, 7, 28) }
        assertEquals(2, firstDay.size)
        assertEquals(
            setOf(PlannedContentReminder.Kind.AZKAR, PlannedContentReminder.Kind.HADITH),
            firstDay.map { it.kind }.toSet(),
        )
    }

    // endregion

    // region Waking window

    @Test
    fun `every fire time is inside the waking window`() {
        for (count in 1..5) {
            plan(perDay = count, horizonDays = 7, budget = 64).forEach { item ->
                val hour = item.localTime().hour
                assertTrue(item.id, hour >= ContentReminderPlanner.WINDOW_START_HOUR)
                assertTrue(item.id, hour < ContentReminderPlanner.WINDOW_END_HOUR)
            }
        }
    }

    @Test
    fun `reminders are sorted and never in the past`() {
        val now = at(2026, 7, 28, 13, 20)
        val all = plan(perDay = 4, now = now, horizonDays = 4, budget = 64)
        assertEquals(all.sortedBy { it.fireEpochSeconds }, all)
        assertTrue(all.all { it.fireEpochSeconds > now.epochSeconds })
    }

    // endregion

    // region Budget

    /**
     * iOS drops the OLDEST pending requests past 64, which would silently delete
     * prayer notifications — so overshooting here is a real bug, not cosmetic.
     */
    @Test
    fun `never exceeds the remaining budget`() {
        val all = plan(perDay = 5, horizonDays = 14)
        assertEquals(ContentReminderPlanner.DEFAULT_BUDGET, all.size)
        assertTrue(all.size <= 16)
    }

    @Test
    fun `remaining budget is what the prayer schedule leaves over`() {
        // NotificationPlanner.DEFAULT_BUDGET is 48 of the OS's 64.
        assertEquals(16, ContentReminderPlanner.remainingBudget(48))
        assertEquals(16, ContentReminderPlanner.DEFAULT_BUDGET)
        assertEquals(0, ContentReminderPlanner.remainingBudget(64))
        assertEquals(0, ContentReminderPlanner.remainingBudget(999))
    }

    @Test
    fun `zero budget emits nothing`() {
        assertTrue(plan(perDay = 5, budget = 0).isEmpty())
    }

    // endregion

    // region Empty pools

    @Test
    fun `both pools empty yields nothing rather than crashing`() {
        assertTrue(plan(azkar = emptyList(), hadith = emptyList()).isEmpty())
    }

    @Test
    fun `one empty pool falls back to the other`() {
        val hadithOnly = plan(perDay = 4, azkar = emptyList(), horizonDays = 2, budget = 64)
        assertTrue(hadithOnly.isNotEmpty())
        assertTrue(hadithOnly.all { it.kind == PlannedContentReminder.Kind.HADITH })

        val azkarOnly = plan(perDay = 4, hadith = emptyList(), horizonDays = 2, budget = 64)
        assertTrue(azkarOnly.isNotEmpty())
        assertTrue(azkarOnly.all { it.kind == PlannedContentReminder.Kind.AZKAR })
    }

    // endregion

    // region Truncation

    @Test
    fun `long text is truncated at a word boundary`() {
        val long = List(60) { "الحمد" }.joinToString(" ")
        val short = ContentReminderPlanner.truncate(long)

        assertTrue(short.length <= ContentReminderPlanner.BODY_CHARACTER_LIMIT)
        assertTrue(short.endsWith("…"))
        // Every surviving token must be a whole word from the source — i.e. the
        // cut landed on a space, not in the middle of "الحمد".
        val kept = short.dropLast(1).trim().split(" ")
        assertTrue(kept.isNotEmpty())
        assertTrue(kept.all { it == "الحمد" })
    }

    @Test
    fun `short text is left alone apart from collapsed whitespace`() {
        assertEquals("سبحان الله وبحمده", ContentReminderPlanner.truncate("سبحان   الله\nوبحمده"))
    }

    /**
     * A single token longer than the limit has no boundary to cut on, so it is
     * hard-cut rather than returned whole (which would blow past the limit).
     */
    @Test
    fun `a word longer than the limit is hard cut`() {
        val short = ContentReminderPlanner.truncate("x".repeat(400), limit = 20)
        assertEquals(20, short.length)
        assertTrue(short.endsWith("…"))
    }

    @Test
    fun `planned bodies respect the limit`() {
        val wordy = listOf(ContentSnippet("h1", List(200) { "كلمة" }.joinToString(" ")))
        val all = plan(perDay = 2, azkar = wordy, hadith = wordy, horizonDays = 3, budget = 64)
        assertTrue(all.isNotEmpty())
        assertTrue(all.all { it.body.length <= ContentReminderPlanner.BODY_CHARACTER_LIMIT })
    }

    // endregion

    // region Deep links

    @Test
    fun `each kind points at its own screen`() {
        assertEquals(DeepLink.AZKAR, PlannedContentReminder.Kind.AZKAR.deepLink)
        assertEquals(DeepLink.HADITH, PlannedContentReminder.Kind.HADITH.deepLink)
        plan(horizonDays = 2, budget = 64).forEach { item ->
            val expected = if (item.kind == PlannedContentReminder.Kind.AZKAR) {
                DeepLink.AZKAR
            } else {
                DeepLink.HADITH
            }
            assertEquals(expected, item.deepLink)
        }
    }

    // endregion

    // region Identifiers

    @Test
    fun `identifiers are stable and unique`() {
        val all = plan(perDay = 5, horizonDays = 3, budget = 64)
        assertEquals(all.size, all.map { it.id }.toSet().size)
        assertTrue(all.all { it.id.startsWith("content-") })
    }

    // endregion

    /**
     * Cross-platform parity check: the same seed must mix to the same value on
     * both platforms, or the two schedules drift apart. The last two inputs are
     * the real `dayKey * 64 + slot` seeds for 2026-07-28, slots 0 and 1.
     * Values captured from the Swift implementation.
     */
    @Test
    fun `splitmix64 matches the iOS implementation`() {
        assertEquals(0xE220A8397B1DCDAFuL, ContentReminderPlanner.splitmix64(0uL))
        assertEquals(0x910A2DEC89025CC1uL, ContentReminderPlanner.splitmix64(1uL))
        assertEquals(0x6E789E6AA1B965F4uL, ContentReminderPlanner.splitmix64(0x9E3779B97F4A7C15uL))
        assertEquals(0x09C3DAC532F5D995uL, ContentReminderPlanner.splitmix64(20260728uL * 64uL))
        assertEquals(0xEDA8B99516FA22CEuL, ContentReminderPlanner.splitmix64(20260728uL * 64uL + 1uL))
    }
}
