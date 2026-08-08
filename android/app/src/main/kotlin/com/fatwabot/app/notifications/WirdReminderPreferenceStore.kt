package com.fatwabot.app.notifications

import android.content.Context
import com.fatwabot.feature.awrad.WirdReminderPreferences
import com.fatwabot.feature.awrad.WirdReminderTime

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
            timesByWird = decodeWirdTimes(prefs.getString(KEY_TIMES, null)),
        )
    }

    fun save(preferences: WirdReminderPreferences) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putBoolean(KEY_ENABLED, preferences.enabled)
            .putInt(KEY_HOUR, WirdReminderPreferences.clampHour(preferences.hour))
            .putInt(KEY_MINUTE, WirdReminderPreferences.clampMinute(preferences.minute))
            .putString(KEY_TIMES, encodeWirdTimes(preferences.timesByWird))
            .apply()
    }

    private companion object {
        const val PREFS = "wird_reminder_preferences"
        const val KEY_ENABLED = "enabled"
        const val KEY_HOUR = "hour"
        const val KEY_MINUTE = "minute"
        const val KEY_TIMES = "times_by_wird"
    }
}

/**
 * Per-wird times as `wirdId=HH:mm` joined by `;`.
 *
 * SharedPreferences has no map type. A string set would lose ordering and still
 * need parsing, and pulling in a JSON dependency for two integers per wird is
 * not worth it.
 *
 * File-scope rather than a method on the store because these are pure — keeping
 * them off a Context-holding class is what makes them testable without
 * Robolectric.
 *
 * Anything unparseable is skipped rather than thrown: a corrupt entry should
 * cost that one override, never every reminder the user has. Same contract the
 * iOS decoder holds.
 */
internal fun decodeWirdTimes(raw: String?): Map<String, WirdReminderTime> {
    if (raw.isNullOrBlank()) return emptyMap()
    return raw.split(';').mapNotNull { entry ->
        val parts = entry.split('=', limit = 2).takeIf { it.size == 2 } ?: return@mapNotNull null
        val (id, clock) = parts
        if (id.isBlank()) return@mapNotNull null
        val clockParts = clock.split(':', limit = 2).takeIf { it.size == 2 } ?: return@mapNotNull null
        val hour = clockParts[0].toIntOrNull() ?: return@mapNotNull null
        val minute = clockParts[1].toIntOrNull() ?: return@mapNotNull null
        id to WirdReminderTime.of(hour, minute)
    }.toMap()
}

internal fun encodeWirdTimes(times: Map<String, WirdReminderTime>): String =
    // Sorted so the stored value is stable across saves — an unordered map would
    // rewrite the same data in a different order every time.
    times.toSortedMap().entries.joinToString(";") { (id, time) ->
        "%s=%02d:%02d".format(id, time.hour, time.minute)
    }
