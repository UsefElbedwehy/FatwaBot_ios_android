package com.fatwabot.core.common

import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ConfigModelsTest {
    private val json = Json { ignoreUnknownKeys = true }

    @Test
    fun `decodes aggregated config payload`() {
        val payload = """
            {
              "config": {"hijri.default_offset_days": 0},
              "flags": {"module.prayer": {"enabled": true, "rollout": {}}, "module.ai_ask": {"enabled": false, "rollout": {}}},
              "locales": [{"locale": "ar", "display_name": "العربية", "direction": "rtl", "digits": "eastern"}]
            }
        """.trimIndent()
        val config = json.decodeFromString<AppConfig>(payload)
        assertTrue(config.isEnabled("module.prayer"))
        assertFalse(config.isEnabled("module.ai_ask"))
        assertFalse("unknown flags default to disabled", config.isEnabled("module.unknown"))
        assertEquals("rtl", config.locales.first().direction)
    }

    @Test
    fun `home layout skips unknown section types`() {
        val payload = """
            {
              "version": 3,
              "sections": [
                {"id": "prayer", "type": "prayer_hero", "props": {}},
                {"id": "future", "type": "hologram_qibla", "props": {"x": 1}},
                {"id": "ask", "type": "ask_ai", "props": {"state": "coming_soon"}}
              ]
            }
        """.trimIndent()
        val layout = json.decodeFromString<HomeLayout>(payload)
        val rendered = layout.renderableSections(setOf("prayer_hero", "ask_ai", "streak_strip"))
        assertEquals(listOf("prayer", "ask"), rendered.map { it.id })
    }
}
