package com.fatwabot.core.config

import com.fatwabot.core.common.AppConfig
import com.fatwabot.core.common.HomeLayout
import com.fatwabot.core.common.PrayerDefaults
import com.fatwabot.core.common.SemVer
import com.fatwabot.core.common.ServerTheme
import com.fatwabot.core.common.StringPack
import com.fatwabot.core.network.ApiClientProtocol
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.json.Json

/**
 * Config sync (ADR-0011 client half) — mirror of iOS ConfigKit.ConfigService.
 * Offline-first: [current] is always readable (cache → empty snapshot whose
 * consumers fall back to bundled values); [refresh] updates layers independently.
 */
class ConfigService(
    private val store: ConfigStoring,
    private val client: ApiClientProtocol,
    private val nowEpochSeconds: () -> Long,
) {
    private val json = Json { ignoreUnknownKeys = true }
    private val mutex = Mutex()

    @Volatile
    var current: ConfigSnapshot = store.load() ?: ConfigSnapshot()
        private set

    /** Fetches all layers concurrently; per-layer failures are silent (spec). */
    suspend fun refresh(locales: List<String>): Set<ConfigLayer> = mutex.withLock {
        coroutineScope {
            val configJob = async { fetch("v1/config") { json.decodeFromString<AppConfig>(it) } }
            val themeJob = async { fetch("v1/config/theme") { json.decodeFromString<ServerTheme>(it) } }
            val layoutJob = async { fetch("v1/home") { json.decodeFromString<HomeLayout>(it) } }

            val packs = locales.mapNotNull { locale ->
                val since = current.stringPacks[locale]?.version
                val query = if (since != null) mapOf("since_version" to since.toString()) else emptyMap()
                fetch("v1/config/strings/$locale", query) {
                    // Server returns {"up_to_date": true} when nothing newer.
                    if (it.contains("\"up_to_date\"")) null else json.decodeFromString<StringPack>(it)
                }?.let { locale to it }
            }.toMap()

            val changed = mutableSetOf<ConfigLayer>()
            var next = current

            configJob.await()?.takeIf { it != next.appConfig }?.let {
                next = next.copy(appConfig = it); changed += ConfigLayer.APP_CONFIG
            }
            themeJob.await()?.takeIf { it != next.theme }?.let {
                next = next.copy(theme = it); changed += ConfigLayer.THEME
            }
            layoutJob.await()?.takeIf { it != next.homeLayout }?.let {
                next = next.copy(homeLayout = it); changed += ConfigLayer.HOME_LAYOUT
            }
            packs.forEach { (locale, pack) ->
                if (pack != next.stringPacks[locale]) {
                    next = next.copy(stringPacks = next.stringPacks + (locale to pack))
                    changed += ConfigLayer.STRINGS
                }
            }

            if (changed.isNotEmpty() || next.fetchedAtEpochSeconds == null) {
                next = next.copy(fetchedAtEpochSeconds = nowEpochSeconds())
                current = next
                store.save(next)
            }
            changed
        }
    }

    /** Server pack overlay → null (caller falls back to bundled strings, then key). */
    fun string(key: String, locale: String): String? =
        current.stringPacks[locale]?.strings?.get(key)

    /** Unknown flag = false; disabled = false; min_app_version gate honored. */
    fun isEnabled(flag: String, appVersion: String): Boolean {
        val entry = current.appConfig?.flags?.get(flag) ?: return false
        if (!entry.enabled) return false
        val min = entry.rollout?.minAppVersion ?: return true
        return SemVer.isVersionAtLeast(appVersion, min)
    }

    fun homeLayout(): HomeLayout? = current.homeLayout
    fun prayerDefaults(): PrayerDefaults? = current.prayerDefaults

    /** GET [path]; any failure (network/parse) → null (silent per spec). */
    private suspend inline fun <T> fetch(
        path: String,
        query: Map<String, String> = emptyMap(),
        decode: (String) -> T?,
    ): T? = runCatching { decode(client.getRaw(path, query)) }.getOrNull()
}
