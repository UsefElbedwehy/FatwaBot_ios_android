package com.fatwabot.core.prayer

import java.io.File
import java.nio.file.Files
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** Mirrors iOS WidgetSnapshotTests. */
class WidgetSnapshotTest {
    private val engine = PrayerEngine()

    private fun timeline(days: Int) =
        engine.timeline(24.7136, 46.6753, 2026, 3, 20, days, PrayerSettings(method = "umm_al_qura"))

    @Test
    fun `build filters to horizon and sorts`() {
        val days = timeline(5)
        val generatedAt = days.first().times.getValue(PrayerNameUi.FAJR).epochSeconds - 3600
        val snapshot = PrayerWidgetSnapshot.build(
            days, "الرياض", HijriDateUi.from(java.time.LocalDate.of(2026, 3, 20), 0), generatedAt,
        )
        assertTrue(snapshot.upcoming.isNotEmpty())
        assertEquals(snapshot.upcoming.sortedBy { it.timeEpochSeconds }, snapshot.upcoming)
        assertTrue(snapshot.upcoming.size <= 12)
        assertTrue(snapshot.upcoming.all { it.timeEpochSeconds <= generatedAt + 48 * 3600 })
        assertFalse(snapshot.upcoming.any { it.prayer == "sunrise" })
    }

    @Test
    fun `store round trip`() {
        val dir = Files.createTempDirectory("widget").toFile()
        val store = WidgetSnapshotStore(File(dir, "snap.json"))
        val days = timeline(2)
        val generatedAt = days.first().times.getValue(PrayerNameUi.FAJR).epochSeconds - 3600
        val snapshot = PrayerWidgetSnapshot.build(
            days, "الرياض", HijriDateUi.from(java.time.LocalDate.of(2026, 3, 20), 0), generatedAt,
        )
        store.write(snapshot)
        assertEquals(snapshot, store.read())
    }
}
