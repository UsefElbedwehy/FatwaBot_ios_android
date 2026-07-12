package com.fatwabot.core.prayer

import java.io.File
import kotlin.math.abs
import kotlinx.datetime.TimeZone
import kotlinx.datetime.toLocalDateTime
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Authority validation (closes the M0 corpus TODO). The golden corpus proves
 * our Kotlin port matches adhan-js; this proves our on-device Umm al-Qura output
 * matches the **official AlAdhan Umm al-Qura** timings (method=4) to the minute,
 * for real Saudi cities — the same fixture the iOS test enforces. Runs offline
 * against the committed fixture.
 */
class AlAdhanValidationTest {

    @Serializable
    data class Fixture(
        val tolerance_minutes: Int,
        val entries: List<Entry>,
    )

    @Serializable
    data class Entry(
        val city: String,
        val latitude: Double,
        val longitude: Double,
        val timezone: String,
        val date: String,
        val method: String,
        val madhab: String,
        val times_local: Map<String, String>,
    )

    private fun fixtureFile(): File {
        var dir: File? = File(System.getProperty("user.dir"))
        while (dir != null) {
            val candidate = File(dir, "content/test-fixtures/prayer-times/aladhan-umm-al-qura.json")
            if (candidate.exists()) return candidate
            dir = dir.parentFile
        }
        error("aladhan-umm-al-qura.json not found above ${System.getProperty("user.dir")}")
    }

    @Test
    fun `on-device umm al-qura matches aladhan authority`() {
        val fixture = Json { ignoreUnknownKeys = true }
            .decodeFromString<Fixture>(fixtureFile().readText())
        assertTrue("fixture should cover several cities × dates", fixture.entries.size >= 12)

        val calculator = PrayerCalculator()
        val failures = mutableListOf<String>()

        for (entry in fixture.entries) {
            val (year, month, day) = entry.date.split("-").map { it.toInt() }
            val times = calculator.times(
                PrayerCalculator.Request(
                    latitude = entry.latitude,
                    longitude = entry.longitude,
                    year = year, month = month, day = day,
                    method = entry.method,
                    madhab = entry.madhab,
                    highLatitudeRule = null,
                ),
            )
            val tz = TimeZone.of(entry.timezone)
            val computed = mapOf(
                "fajr" to times.fajr, "sunrise" to times.sunrise, "dhuhr" to times.dhuhr,
                "asr" to times.asr, "maghrib" to times.maghrib, "isha" to times.isha,
            )
            for ((prayer, hhmm) in entry.times_local) {
                val ldt = computed.getValue(prayer).toLocalDateTime(tz)
                // Round to nearest minute to match AlAdhan's minute-rounded output.
                val ours = ldt.hour * 60 + ldt.minute + if (ldt.second >= 30) 1 else 0
                val (hh, mm) = hhmm.split(":").map { it.toInt() }
                val theirs = hh * 60 + mm
                val diff = abs(ours - theirs)
                if (diff > fixture.tolerance_minutes) {
                    failures += "${entry.city} ${entry.date} $prayer: ours=${ours / 60}:${ours % 60} authority=$hhmm Δ=${diff}min"
                }
            }
        }

        assertTrue(
            "Umm al-Qura diverges from the AlAdhan authority:\n" + failures.joinToString("\n"),
            failures.isEmpty(),
        )
    }
}
