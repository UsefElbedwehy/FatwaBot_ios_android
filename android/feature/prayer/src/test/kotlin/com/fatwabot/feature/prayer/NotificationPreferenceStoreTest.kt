package com.fatwabot.feature.prayer

import com.fatwabot.core.prayer.PrayerNameUi
import com.fatwabot.core.prayer.PrayerNotificationPreferences
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Mirrors iOS IqamaOffsetMigrationTests. iOS decodes one JSON blob; Android
 * reads individual SharedPreferences keys — the shapes differ, the guarantee
 * does not: upgrading must never silently reset a user's iqama settings.
 */
class NotificationPreferenceStoreTest {

    /** In-memory stand-in for SharedPreferences. */
    private class FakeBackend(initial: Map<String, Any> = emptyMap()) : PreferenceBackend {
        val values = initial.toMutableMap()

        override fun contains(key: String) = values.containsKey(key)
        override fun getBoolean(key: String, fallback: Boolean) = values[key] as? Boolean ?: fallback
        override fun getInt(key: String, fallback: Int) = values[key] as? Int ?: fallback

        override fun write(booleans: Map<String, Boolean>, ints: Map<String, Int>, removals: Set<String>) {
            values.putAll(booleans)
            values.putAll(ints)
            removals.forEach { values.remove(it) }
        }
    }

    private val prayers = PrayerNameUi.entries.filter { it.isPrayer }

    private fun iqamaKey(prayer: PrayerNameUi) = "iqama_offset_${prayer.key}"

    @Test
    fun `first run yields the mosque defaults`() {
        val prefs = NotificationPreferenceStore(FakeBackend()).load()
        assertEquals(20, prefs.iqamaOffset(PrayerNameUi.FAJR))
        prayers.filter { it != PrayerNameUi.FAJR }.forEach {
            assertEquals("$it should default to 10", 10, prefs.iqamaOffset(it))
        }
    }

    /** Exactly what an already-installed device has stored. */
    @Test
    fun `legacy single value is carried onto every prayer`() {
        val backend = FakeBackend(
            mapOf(
                "adhan_enabled" to true,
                "pre_adhan_enabled" to true,
                "pre_adhan_offset" to 15,
                "iqama_enabled" to true,
                "iqama_offset" to 15,
                "last_third_enabled" to false,
            ),
        )
        val prefs = NotificationPreferenceStore(backend).load()

        assertTrue("the user's on/off choice must survive", prefs.iqamaEnabled)
        assertEquals(15, prefs.clampedPreAdhan)
        prayers.forEach { assertEquals("legacy 15 should carry to $it", 15, prefs.iqamaOffset(it)) }
    }

    @Test
    fun `legacy value is clamped on migration`() {
        val prefs = NotificationPreferenceStore(FakeBackend(mapOf("iqama_offset" to 9999))).load()
        prayers.forEach { assertEquals(60, prefs.iqamaOffset(it)) }
    }

    /** A disabled user stays disabled — migration must not flip the toggle. */
    @Test
    fun `legacy migration preserves a disabled toggle`() {
        val prefs = NotificationPreferenceStore(
            FakeBackend(mapOf("iqama_enabled" to false, "iqama_offset" to 12)),
        ).load()
        assertFalse(prefs.iqamaEnabled)
        prayers.forEach { assertEquals(12, prefs.iqamaOffset(it)) }
    }

    /** Once per-prayer keys exist they win; the legacy value is not consulted. */
    @Test
    fun `per prayer keys take precedence over the legacy key`() {
        val backend = FakeBackend(
            mapOf("iqama_offset" to 15, iqamaKey(PrayerNameUi.FAJR) to 25, iqamaKey(PrayerNameUi.ASR) to 8),
        )
        val prefs = NotificationPreferenceStore(backend).load()
        assertEquals(25, prefs.iqamaOffset(PrayerNameUi.FAJR))
        assertEquals(8, prefs.iqamaOffset(PrayerNameUi.ASR))
        // Absent keys fall back to the default rather than to the legacy 15,
        // so a partially written set can't drop a prayer's reminder.
        assertEquals(10, prefs.iqamaOffset(PrayerNameUi.ISHA))
    }

    @Test
    fun `round trip preserves every prayer`() {
        val backend = FakeBackend()
        val store = NotificationPreferenceStore(backend)
        store.save(
            PrayerNotificationPreferences(iqamaEnabled = true).withIqamaOffset(PrayerNameUi.MAGHRIB, 5),
        )
        val restored = store.load()
        assertTrue(restored.iqamaEnabled)
        assertEquals(5, restored.iqamaOffset(PrayerNameUi.MAGHRIB))
        assertEquals(20, restored.iqamaOffset(PrayerNameUi.FAJR))
        assertEquals(10, restored.iqamaOffset(PrayerNameUi.ISHA))
    }

    /** The legacy key is read once for migration and never written back. */
    @Test
    fun `saving drops the legacy key`() {
        val backend = FakeBackend(mapOf("iqama_enabled" to true, "iqama_offset" to 15))
        val store = NotificationPreferenceStore(backend)

        store.save(store.load())

        assertFalse("legacy key should not survive a save", backend.values.containsKey("iqama_offset"))
        prayers.forEach { assertEquals(15, backend.values[iqamaKey(it)]) }
        // And the migrated values stick on the next read.
        prayers.forEach { assertEquals(15, store.load().iqamaOffset(it)) }
    }
}
