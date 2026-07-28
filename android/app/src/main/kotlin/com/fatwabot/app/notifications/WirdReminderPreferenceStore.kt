package com.fatwabot.app.notifications

import android.content.Context
import com.fatwabot.feature.awrad.WirdReminderPreferences

/**
 * Persistence for the daily wird reminder settings.
 *
 * Its own SharedPreferences file, for the same reason [ContentReminderPreferenceStore]
 * is separate from `notification_preferences`: the three are edited independently,
 * and sharing a file would risk one feature's migration clearing another's keys.
 */
class WirdReminderPreferenceStore(private val context: Context) {

    fun load(): WirdReminderPreferences {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val defaults = WirdReminderPreferences()
        return WirdReminderPreferences(
            enabled = prefs.getBoolean(KEY_ENABLED, defaults.enabled),
            hour = WirdReminderPreferences.clampHour(prefs.getInt(KEY_HOUR, defaults.hour)),
            minute = WirdReminderPreferences.clampMinute(prefs.getInt(KEY_MINUTE, defaults.minute)),
        )
    }

    fun save(preferences: WirdReminderPreferences) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putBoolean(KEY_ENABLED, preferences.enabled)
            .putInt(KEY_HOUR, WirdReminderPreferences.clampHour(preferences.hour))
            .putInt(KEY_MINUTE, WirdReminderPreferences.clampMinute(preferences.minute))
            .apply()
    }

    private companion object {
        const val PREFS = "wird_reminder_preferences"
        const val KEY_ENABLED = "enabled"
        const val KEY_HOUR = "hour"
        const val KEY_MINUTE = "minute"
    }
}
