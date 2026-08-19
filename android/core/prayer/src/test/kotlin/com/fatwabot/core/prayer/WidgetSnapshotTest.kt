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

    // MARK: - Day sheets (mirrors iOS WidgetSnapshotTests)

    private fun snapshot(days: Int): Pair<List<PrayerDayUi>, PrayerWidgetSnapshot> {
        val timeline = timeline(days)
        val generatedAt = timeline.first().times.getValue(PrayerNameUi.FAJR).epochSeconds - 3600
        return timeline to PrayerWidgetSnapshot.build(
            timeline, "الرياض", HijriDateUi.from(java.time.LocalDate.of(2026, 3, 20), 0), generatedAt,
        )
    }

    @Test
    fun `day sheet keeps sunrise that upcoming drops`() {
        val (timeline, snap) = snapshot(3)
        val at = timeline.first().times.getValue(PrayerNameUi.FAJR).epochSeconds
        val sheet = requireNotNull(snap.sheet(at))
        // The whole point of the second pass: sunrise is absent from `upcoming`
        // and present here.
        assertTrue(sheet.times.any { it.prayer == "sunrise" })
        assertEquals(PrayerNameUi.values().size, sheet.times.size)
        assertEquals(sheet.times.sortedBy { it.timeEpochSeconds }, sheet.times)
    }

    @Test
    fun `night markers match the notification planner's last third`() {
        val (timeline, snap) = snapshot(3)
        val sheet = requireNotNull(snap.sheet(timeline.first().times.getValue(PrayerNameUi.FAJR).epochSeconds))
        val maghrib = timeline.first().times.getValue(PrayerNameUi.MAGHRIB).epochSeconds
        val nextFajr = timeline[1].times.getValue(PrayerNameUi.FAJR).epochSeconds
        val night = nextFajr - maghrib

        // Independently recomputed rather than read back from NightTimes, so this
        // fails if the shared definition is ever changed underneath it.
        assertEquals(maghrib + night * 2L / 3L, sheet.lastThirdEpochSeconds)
        assertEquals(maghrib + night / 2L, sheet.midnightEpochSeconds)
        assertTrue(sheet.midnightEpochSeconds!! < sheet.lastThirdEpochSeconds!!)
    }

    @Test
    fun `final day has no night markers rather than wrong ones`() {
        val (_, snap) = snapshot(2)
        // The last day has no successor to take Fajr from. Absent beats invented.
        val last = snap.days.last()
        assertEquals(null, last.midnightEpochSeconds)
        assertEquals(null, last.lastThirdEpochSeconds)
    }

    @Test
    fun `sheet keeps the previous day through the small hours`() {
        val (_, snap) = snapshot(3)
        val first = snap.days.first()
        // Standing *in* the last third — past clock midnight, before the next
        // Fajr. The sheet must still be the one whose night this is.
        val resolved = requireNotNull(snap.sheet(first.lastThirdEpochSeconds!! + 60))
        assertEquals(first.fajrEpochSeconds, resolved.fajrEpochSeconds)
    }

    @Test
    fun `decodes snapshot written before day sheets existed`() {
        // A v1 payload: no `days` key. The widget process reads this whenever the
        // new build runs before the app has rewritten the snapshot.
        val json = """{"locationName":"الرياض","hijriMonthName":"صفر","hijriDay":25,
            "hijriYear":1448,"upcoming":[{"prayer":"fajr","timeEpochSeconds":1786240000}],
            "generatedAtEpochSeconds":1786230000}""".trimIndent()
        val dir = Files.createTempDirectory("snap").toFile()
        val file = File(dir, "prayer-widget-snapshot.json")
        file.writeText(json)
        val decoded = requireNotNull(WidgetSnapshotStore(file).read())
        // Decoding must succeed — the countdown widgets keep working...
        assertEquals(1, decoded.upcoming.size)
        assertEquals("الرياض", decoded.locationName)
        // ...and only the day sheet is unavailable.
        assertTrue(decoded.days.isEmpty())
        assertEquals(null, decoded.sheet(1786240000L))
    }
}
