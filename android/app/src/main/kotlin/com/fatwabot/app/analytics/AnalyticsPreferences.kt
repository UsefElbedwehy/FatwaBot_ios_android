package com.fatwabot.app.analytics

import android.content.Context
import android.content.SharedPreferences

/**
 * The user's diagnostics choice. Persisted locally only — it gates the SDKs
 * themselves, so it can't be a server-config value (we must know it before the
 * first network call, and offline).
 *
 * Defaults to enabled: crash reports are what make a bug fixable, and nothing
 * personal is collected (see [com.fatwabot.core.common.AnalyticsTracking]). The
 * opt-out exists because this is a worship app — a user who would rather send
 * nothing at all should not have to uninstall to get that.
 */
class AnalyticsPreferences(context: Context) {
    private val prefs: SharedPreferences =
        context.getSharedPreferences("fatwabot_diagnostics", Context.MODE_PRIVATE)

    var isEnabled: Boolean
        get() = prefs.getBoolean(KEY_ENABLED, true)
        set(value) = prefs.edit().putBoolean(KEY_ENABLED, value).apply()

    private companion object {
        const val KEY_ENABLED = "diagnostics.enabled"
    }
}
