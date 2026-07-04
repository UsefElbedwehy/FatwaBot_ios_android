package com.fatwabot.core.prayer

import java.time.LocalDate
import kotlinx.datetime.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Mirrors iOS PrayerEngineTests — both engines must behave identically. */
class PrayerEngineTest {
    private val engine = PrayerEngine()
    private val settings = PrayerSettings(method = "umm_al_qura")

    private fun riyadhDay(s: PrayerSettings = settings) =
        engine.day(24.7136, 46.6753, 2026, 3, 20, s)

    @Test
    fun `adjustments shift only target prayer`() {
        val base = riyadhDay()
        val adjusted = riyadhDay(
            settings.copy(adjustmentsMinutes = mapOf(PrayerNameUi.FAJR to 5, PrayerNameUi.ISHA to -10)),
        )
        assertEquals(300L, adjusted.times.getValue(PrayerNameUi.FAJR).epochSeconds - base.times.getValue(PrayerNameUi.FAJR).epochSeconds)
        assertEquals(-600L, adjusted.times.getValue(PrayerNameUi.ISHA).epochSeconds - base.times.getValue(PrayerNameUi.ISHA).epochSeconds)
        assertEquals(base.times.getValue(PrayerNameUi.DHUHR), adjusted.times.getValue(PrayerNameUi.DHUHR))
    }

    @Test
    fun `adjustments are clamped`() {
        val s = PrayerSettings(adjustmentsMinutes = mapOf(PrayerNameUi.FAJR to 90, PrayerNameUi.ASR to -90))
        assertEquals(30, s.clampedAdjustments.getValue(PrayerNameUi.FAJR))
        assertEquals(-30, s.clampedAdjustments.getValue(PrayerNameUi.ASR))
    }

    @Test
    fun `next prayer mid day`() {
        val today = riyadhDay()
        val now = Instant.fromEpochSeconds(today.times.getValue(PrayerNameUi.DHUHR).epochSeconds + 60)
        val state = PrayerEngine.nextPrayer(now, today, today)
        assertEquals(PrayerNameUi.DHUHR, state.current)
        assertEquals(PrayerNameUi.ASR, state.next)
    }

    @Test
    fun `next prayer skips sunrise`() {
        val today = riyadhDay()
        val now = Instant.fromEpochSeconds(today.times.getValue(PrayerNameUi.FAJR).epochSeconds + 60)
        val state = PrayerEngine.nextPrayer(now, today, today)
        assertEquals(PrayerNameUi.FAJR, state.current)
        assertEquals(PrayerNameUi.DHUHR, state.next)
    }

    @Test
    fun `after isha rolls to tomorrow fajr`() {
        val today = riyadhDay()
        val tomorrow = engine.day(24.7136, 46.6753, 2026, 3, 21, settings)
        val now = Instant.fromEpochSeconds(today.times.getValue(PrayerNameUi.ISHA).epochSeconds + 3600)
        val state = PrayerEngine.nextPrayer(now, today, tomorrow)
        assertEquals(PrayerNameUi.ISHA, state.current)
        assertEquals(PrayerNameUi.FAJR, state.next)
        assertTrue(state.nextTime > now)
    }

    @Test
    fun `before fajr has no current prayer`() {
        val today = riyadhDay()
        val now = Instant.fromEpochSeconds(today.times.getValue(PrayerNameUi.FAJR).epochSeconds - 3600)
        val state = PrayerEngine.nextPrayer(now, today, today)
        assertNull(state.current)
        assertEquals(PrayerNameUi.FAJR, state.next)
    }

    @Test
    fun `timeline produces consecutive days`() {
        val days = engine.timeline(24.7136, 46.6753, 2026, 3, 20, 5, settings)
        assertEquals(5, days.size)
        days.zipWithNext().forEach { (a, b) ->
            val gap = b.times.getValue(PrayerNameUi.FAJR).epochSeconds - a.times.getValue(PrayerNameUi.FAJR).epochSeconds
            assertTrue("fajr-to-fajr gap ~24h, got $gap", kotlin.math.abs(gap - 86_400) < 300)
        }
    }

    @Test
    fun `high latitude auto rule applied above threshold`() {
        assertNotNull(PrayerEngine.effectiveHighLatitudeRule(PrayerSettings(method = "mwl"), 59.91))
        assertNull(PrayerEngine.effectiveHighLatitudeRule(PrayerSettings(method = "umm_al_qura"), 24.7))
        assertEquals(
            "twilight_angle",
            PrayerEngine.effectiveHighLatitudeRule(
                PrayerSettings(method = "mwl", highLatitudeRule = "twilight_angle"), 10.0,
            ),
        )
    }

    @Test
    fun `hijri offset equals next civil day`() {
        val date = LocalDate.of(2026, 3, 20)
        val base = HijriDateUi.from(date, 0)
        val plusOne = HijriDateUi.from(date, 1)
        val nextDay = HijriDateUi.from(date.plusDays(1), 0)
        assertEquals(1447, base.year)
        assertEquals(nextDay, plusOne)
    }
}
