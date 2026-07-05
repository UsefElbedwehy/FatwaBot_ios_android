package com.fatwabot.core.common

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject

// Server contract models — mirror backend/openapi/api.v1.yaml (parity with iOS CoreKit).

@Serializable
data class AppConfig(
    val config: JsonObject,
    val flags: Map<String, Flag>,
    val locales: List<LocaleInfo>,
) {
    @Serializable
    data class Flag(val enabled: Boolean, val rollout: Rollout? = null) {
        @Serializable
        data class Rollout(
            @SerialName("min_app_version") val minAppVersion: String? = null,
        )
    }

    fun isEnabled(flag: String): Boolean = flags[flag]?.enabled ?: false
}

@Serializable
data class LocaleInfo(
    val locale: String,
    @SerialName("display_name") val displayName: String,
    val direction: String,
    val digits: String,
)

@Serializable
data class ServerTheme(
    val version: Int,
    val tokens: JsonObject,
)

@Serializable
data class StringPack(
    val locale: String,
    val version: Int,
    val strings: Map<String, String>,
)

@Serializable
data class HomeLayout(
    val version: Int,
    val sections: List<Section>,
) {
    @Serializable
    data class Section(
        val id: String,
        val type: String,
        val props: JsonObject,
    )

    /** ADR-0011 forward compatibility: unknown section types are skipped, never fatal. */
    fun renderableSections(supported: Set<String>): List<Section> =
        sections.filter { it.type in supported }
}

@Serializable
data class PrayerDefaults(
    @SerialName("country_code") val countryCode: String,
    val method: String,
    val params: JsonElement,
)
