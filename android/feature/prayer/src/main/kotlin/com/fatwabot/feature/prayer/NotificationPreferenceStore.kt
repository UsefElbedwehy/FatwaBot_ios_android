package com.fatwabot.feature.prayer

import android.content.Context
import com.fatwabot.core.prayer.PrayerNameUi
import com.fatwabot.core.prayer.PrayerNotificationPreferences

/**
 * Minimal key/value surface the store maps preferences onto. It exists so the
 * mapping — in particular the pre-2026-07 iqama migration — is unit-testable
 * without an Android runtime; production always uses [SharedPreferencesBackend].
 */
internal interface PreferenceBackend {
    fun contains(key: String): Boolean
    fun getBoolean(key: String, fallback: Boolean): Boolean
    fun getInt(key: String, fallback: Int): Int
    fun write(booleans: Map<String, Boolean>, ints: Map<String, Int>, removals: Set<String>)
}

internal class SharedPreferencesBackend(context: Context) : PreferenceBackend {
    private val prefs = context.getSharedPreferences("notification_preferences", Context.MODE_PRIVATE)

    override fun contains(key: String) = prefs.contains(key)
    override fun getBoolean(key: String, fallback: Boolean) = prefs.getBoolean(key, fallback)
    override fun getInt(key: String, fallback: Int) = prefs.getInt(key, fallback)

    override fun write(booleans: Map<String, Boolean>, ints: Map<String, Int>, removals: Set<String>) {
        prefs.edit().apply {
            booleans.forEach { (k, v) -> putBoolean(k, v) }
            ints.forEach { (k, v) -> putInt(k, v) }
            removals.forEach { remove(it) }
        }.apply()
    }
}

/**
 * Persists the user's per-type notification preferences — mirror of iOS
 * NotificationPreferenceStore. Stored as individual SharedPreferences keys so
 * the feature module needs no serialization dependency (iOS stores one JSON
 * blob; the migration reasoning below is the same on both sides).
 */
class NotificationPreferenceStore internal constructor(private val backend: PreferenceBackend) {

    constructor(context: Context) : this(SharedPreferencesBackend(context))

    fun load(): PrayerNotificationPreferences {
        val d = PrayerNotificationPreferences() // defaults
        return PrayerNotificationPreferences(
            adhanEnabled = backend.getBoolean(K_ADHAN, d.adhanEnabled),
            preAdhanEnabled = backend.getBoolean(K_PRE, d.preAdhanEnabled),
            preAdhanOffsetMinutes = backend.getInt(K_PRE_OFF, d.preAdhanOffsetMinutes),
            iqamaEnabled = backend.getBoolean(K_IQAMA, d.iqamaEnabled),
            iqamaOffsetsByPrayer = loadIqamaOffsets(),
            lastThirdEnabled = backend.getBoolean(K_LAST_THIRD, d.lastThirdEnabled),
        )
    }

    /**
     * Per-prayer gaps, with the pre-2026-07 single-value key carried forward.
     *
     * An installed device only has `iqama_offset`: one gap shared by every
     * prayer. Reading just the new keys would hand that user the 20/10 defaults
     * and silently discard whatever they chose — the kind of bug nobody reports,
     * they just find their config gone. So when no per-prayer key exists yet, the
     * old value is copied onto every prayer. (`iqama_enabled` is untouched by the
     * change, so their on/off choice survives on its own.) The legacy key is
     * never written again — [save] deletes it.
     */
    private fun loadIqamaOffsets(): Map<String, Int> {
        val stored = PRAYERS
            .filter { backend.contains(iqamaKey(it)) }
            .associate { it.key to backend.getInt(iqamaKey(it), PrayerNotificationPreferences.DEFAULT_IQAMA_OFFSET_MINUTES) }
        // A partial map is left partial on purpose: PrayerNotificationPreferences
        // .iqamaOffset() falls back per prayer, so a missing key yields the mosque
        // default rather than dropping that prayer's reminder.
        if (stored.isNotEmpty()) return stored

        if (backend.contains(K_IQAMA_OFF_LEGACY)) {
            val legacy = PrayerNotificationPreferences.clamp(
                backend.getInt(K_IQAMA_OFF_LEGACY, PrayerNotificationPreferences.DEFAULT_IQAMA_OFFSET_MINUTES),
            )
            return PRAYERS.associate { it.key to legacy }
        }

        return PrayerNotificationPreferences.DEFAULT_IQAMA_OFFSETS
    }

    fun save(p: PrayerNotificationPreferences) {
        backend.write(
            booleans = mapOf(
                K_ADHAN to p.adhanEnabled,
                K_PRE to p.preAdhanEnabled,
                K_IQAMA to p.iqamaEnabled,
                K_LAST_THIRD to p.lastThirdEnabled,
            ),
            ints = buildMap {
                put(K_PRE_OFF, p.clampedPreAdhan)
                PRAYERS.forEach { put(iqamaKey(it), p.iqamaOffset(it)) }
            },
            // Read once for migration, then gone: leaving it would keep a stale
            // number around that a future reader could mistake for live config.
            removals = setOf(K_IQAMA_OFF_LEGACY),
        )
    }

    internal companion object {
        val PRAYERS = PrayerNameUi.entries.filter { it.isPrayer }

        const val K_ADHAN = "adhan_enabled"
        const val K_PRE = "pre_adhan_enabled"
        const val K_PRE_OFF = "pre_adhan_offset"
        const val K_IQAMA = "iqama_enabled"
        const val K_LAST_THIRD = "last_third_enabled"

        /** Pre-2026-07 shape: one gap shared by every prayer. Read-only now. */
        const val K_IQAMA_OFF_LEGACY = "iqama_offset"

        fun iqamaKey(prayer: PrayerNameUi) = "iqama_offset_${prayer.key}"
    }
}
