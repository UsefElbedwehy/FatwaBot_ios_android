package com.fatwabot.core.prayer

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Mirrors the model half of iOS IqamaOffsetMigrationTests — both platforms must
 * agree on the defaults, the per-prayer fallback and the clamp.
 */
class PrayerNotificationPreferencesTest {

    @Test
    fun `defaults follow mosque convention`() {
        val prefs = PrayerNotificationPreferences()
        assertEquals(20, prefs.iqamaOffset(PrayerNameUi.FAJR))
        for (prayer in listOf(PrayerNameUi.DHUHR, PrayerNameUi.ASR, PrayerNameUi.MAGHRIB, PrayerNameUi.ISHA)) {
            assertEquals("$prayer should default to 10", 10, prefs.iqamaOffset(prayer))
        }
    }

    /** Sunrise is not a prayer, so it is absent from the defaults entirely. */
    @Test
    fun `defaults cover exactly the five prayers`() {
        assertEquals(
            setOf("fajr", "dhuhr", "asr", "maghrib", "isha"),
            PrayerNotificationPreferences.DEFAULT_IQAMA_OFFSETS.keys,
        )
    }

    /** Keys are byte-identical to iOS PrayerName.rawValue. */
    @Test
    fun `prayer keys match the ios raw values`() {
        assertEquals(
            listOf("fajr", "sunrise", "dhuhr", "asr", "maghrib", "isha"),
            PrayerNameUi.entries.map { it.key },
        )
    }

    @Test
    fun `partial map falls back per prayer`() {
        val prefs = PrayerNotificationPreferences(iqamaOffsetsByPrayer = mapOf("fajr" to 25))
        assertEquals(25, prefs.iqamaOffset(PrayerNameUi.FAJR))
        assertEquals(10, prefs.iqamaOffset(PrayerNameUi.ISHA))
    }

    @Test
    fun `offsets are clamped`() {
        val prefs = PrayerNotificationPreferences(iqamaOffsetsByPrayer = mapOf("fajr" to 9999, "asr" to 0))
        assertEquals(60, prefs.iqamaOffset(PrayerNameUi.FAJR))
        assertEquals(1, prefs.iqamaOffset(PrayerNameUi.ASR))

        val edited = PrayerNotificationPreferences().withIqamaOffset(PrayerNameUi.ISHA, 9999)
        assertEquals(60, edited.iqamaOffset(PrayerNameUi.ISHA))
    }

    @Test
    fun `editing one prayer leaves the others alone`() {
        val prefs = PrayerNotificationPreferences().withIqamaOffset(PrayerNameUi.ASR, 25)
        assertEquals(25, prefs.iqamaOffset(PrayerNameUi.ASR))
        assertEquals(20, prefs.iqamaOffset(PrayerNameUi.FAJR))
        assertEquals(10, prefs.iqamaOffset(PrayerNameUi.MAGHRIB))
    }
}
