package com.fatwabot.feature.prayer

import android.content.Context
import com.fatwabot.core.prayer.PrayerNotificationPreferences

/**
 * Persists the user's per-type notification preferences — mirror of iOS
 * NotificationPreferenceStore. Stored as individual SharedPreferences keys so
 * the feature module needs no serialization dependency.
 */
class NotificationPreferenceStore(context: Context) {
    private val prefs = context.getSharedPreferences(NAME, Context.MODE_PRIVATE)

    fun load(): PrayerNotificationPreferences {
        val d = PrayerNotificationPreferences() // defaults
        return PrayerNotificationPreferences(
            adhanEnabled = prefs.getBoolean(K_ADHAN, d.adhanEnabled),
            preAdhanEnabled = prefs.getBoolean(K_PRE, d.preAdhanEnabled),
            preAdhanOffsetMinutes = prefs.getInt(K_PRE_OFF, d.preAdhanOffsetMinutes),
            iqamaEnabled = prefs.getBoolean(K_IQAMA, d.iqamaEnabled),
            iqamaOffsetMinutes = prefs.getInt(K_IQAMA_OFF, d.iqamaOffsetMinutes),
            lastThirdEnabled = prefs.getBoolean(K_LAST_THIRD, d.lastThirdEnabled),
        )
    }

    fun save(p: PrayerNotificationPreferences) {
        prefs.edit()
            .putBoolean(K_ADHAN, p.adhanEnabled)
            .putBoolean(K_PRE, p.preAdhanEnabled)
            .putInt(K_PRE_OFF, p.clampedPreAdhan)
            .putBoolean(K_IQAMA, p.iqamaEnabled)
            .putInt(K_IQAMA_OFF, p.clampedIqama)
            .putBoolean(K_LAST_THIRD, p.lastThirdEnabled)
            .apply()
    }

    private companion object {
        const val NAME = "notification_preferences"
        const val K_ADHAN = "adhan_enabled"
        const val K_PRE = "pre_adhan_enabled"
        const val K_PRE_OFF = "pre_adhan_offset"
        const val K_IQAMA = "iqama_enabled"
        const val K_IQAMA_OFF = "iqama_offset"
        const val K_LAST_THIRD = "last_third_enabled"
    }
}
