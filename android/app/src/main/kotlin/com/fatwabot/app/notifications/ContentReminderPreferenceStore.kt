package com.fatwabot.app.notifications

import android.content.Context
import com.fatwabot.core.content.ContentReminderPreferences

/**
 * Persistence for the daily azkar/hadith reminder settings.
 *
 * Deliberately a separate SharedPreferences file from `notification_preferences`
 * (the prayer settings) — the two are edited independently, and sharing a file
 * would risk one feature's migration clearing the other's keys. Flat keys rather
 * than a serialized blob, matching `NotificationPreferenceStore`'s house style.
 */
class ContentReminderPreferenceStore(private val context: Context) {

    fun load(): ContentReminderPreferences {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val defaults = ContentReminderPreferences()
        return ContentReminderPreferences(
            enabled = prefs.getBoolean(KEY_ENABLED, defaults.enabled),
            perDay = ContentReminderPreferences.clamp(prefs.getInt(KEY_PER_DAY, defaults.perDay)),
        )
    }

    fun save(preferences: ContentReminderPreferences) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putBoolean(KEY_ENABLED, preferences.enabled)
            .putInt(KEY_PER_DAY, ContentReminderPreferences.clamp(preferences.perDay))
            .apply()
    }

    private companion object {
        const val PREFS = "content_reminder_preferences"
        const val KEY_ENABLED = "enabled"
        const val KEY_PER_DAY = "per_day"
    }
}
