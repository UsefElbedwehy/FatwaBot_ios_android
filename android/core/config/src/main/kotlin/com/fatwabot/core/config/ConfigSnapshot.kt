package com.fatwabot.core.config

import com.fatwabot.core.common.AppConfig
import com.fatwabot.core.common.HomeLayout
import com.fatwabot.core.common.PrayerDefaults
import com.fatwabot.core.common.ServerTheme
import com.fatwabot.core.common.StringPack
import kotlinx.serialization.Serializable

/**
 * Persisted result of config sync — mirror of iOS ConfigKit.ConfigSnapshot.
 * Layers are independent: a failed/malformed layer never blocks the others.
 */
@Serializable
data class ConfigSnapshot(
    val appConfig: AppConfig? = null,
    val theme: ServerTheme? = null,
    val stringPacks: Map<String, StringPack> = emptyMap(),
    val homeLayout: HomeLayout? = null,
    val prayerDefaults: PrayerDefaults? = null,
    val fetchedAtEpochSeconds: Long? = null,
)

enum class ConfigLayer { APP_CONFIG, THEME, STRINGS, HOME_LAYOUT, PRAYER_DEFAULTS }

/** Persistence boundary. File-backed in production; in-memory in tests. */
interface ConfigStoring {
    fun load(): ConfigSnapshot?
    fun save(snapshot: ConfigSnapshot)
}
