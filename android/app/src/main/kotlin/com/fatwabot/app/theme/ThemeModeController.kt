package com.fatwabot.app.theme

import android.content.Context
import android.content.res.Configuration
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

/** User-chosen appearance, applied app-wide by overriding the composition's
 * uiMode so every `isSystemInDarkTheme()` read reflects it (no per-screen
 * change). Persisted so it survives restarts. */
enum class ThemeMode { SYSTEM, LIGHT, DARK }

object ThemeModeController {
    private const val PREFS = "appearance_prefs"
    private const val KEY = "theme_mode"

    var mode by mutableStateOf(ThemeMode.SYSTEM)
        private set

    fun init(context: Context) {
        val raw = context.applicationContext
            .getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY, ThemeMode.SYSTEM.name)
        mode = runCatching { ThemeMode.valueOf(raw ?: "SYSTEM") }.getOrDefault(ThemeMode.SYSTEM)
    }

    fun set(context: Context, next: ThemeMode) {
        mode = next
        context.applicationContext
            .getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY, next.name)
            .apply()
    }

    /** Returns a copy of [base] with its night-mode bit forced per [mode]
     * (SYSTEM leaves it untouched). */
    fun applied(base: Configuration): Configuration {
        val night = when (mode) {
            ThemeMode.SYSTEM -> return base
            ThemeMode.LIGHT -> Configuration.UI_MODE_NIGHT_NO
            ThemeMode.DARK -> Configuration.UI_MODE_NIGHT_YES
        }
        return Configuration(base).apply {
            uiMode = (uiMode and Configuration.UI_MODE_NIGHT_MASK.inv()) or night
        }
    }
}
