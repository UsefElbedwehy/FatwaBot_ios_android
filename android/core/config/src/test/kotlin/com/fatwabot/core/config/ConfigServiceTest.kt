package com.fatwabot.core.config

import com.fatwabot.core.common.SemVer
import com.fatwabot.core.network.ApiClientProtocol
import com.fatwabot.core.network.ApiException
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Parity with iOS ConfigServiceTests — the five spec cases (docs/features/config-sync.md). */
class ConfigServiceTest {

    private class InMemoryStore(var snapshot: ConfigSnapshot? = null) : ConfigStoring {
        var saveCount = 0
        override fun load() = snapshot
        override fun save(snapshot: ConfigSnapshot) {
            this.snapshot = snapshot; saveCount++
        }
    }

    /** Path-keyed stub; missing entry throws (simulating failure). */
    private class StubClient(val responses: MutableMap<String, String> = mutableMapOf()) : ApiClientProtocol {
        override suspend fun getRaw(path: String, query: Map<String, String>): String =
            responses[path] ?: throw ApiException.Transport("stubbed failure for $path")
    }

    private fun fullResponses() = mutableMapOf(
        "v1/config" to """
            {"config": {"x": 1},
             "flags": {"module.prayer": {"enabled": true, "rollout": {}},
                       "module.ai_ask": {"enabled": true, "rollout": {"min_app_version": "2.0.0"}}},
             "locales": [{"locale": "ar", "display_name": "العربية", "direction": "rtl", "digits": "eastern"}]}
        """.trimIndent(),
        "v1/config/theme" to """{"version": 4, "tokens": {"product_name": "Companion"}}""",
        "v1/home" to """{"version": 2, "sections": [{"id": "p", "type": "prayer_hero", "props": {}}]}""",
        "v1/config/strings/ar" to """{"locale": "ar", "version": 7, "strings": {"k": "قيمة"}}""",
    )

    private fun service(store: ConfigStoring, client: ApiClientProtocol) =
        ConfigService(store, client, nowEpochSeconds = { 1000L })

    @Test
    fun `first launch offline yields empty snapshot without error`() = runTest {
        val svc = service(InMemoryStore(), StubClient())
        assertNull(svc.current.appConfig)
        assertEquals(emptySet<ConfigLayer>(), svc.refresh(listOf("ar")))
    }

    @Test
    fun `refresh persists changed layers and second refresh is no-op`() = runTest {
        val store = InMemoryStore()
        val svc = service(store, StubClient(fullResponses()))

        val changed = svc.refresh(listOf("ar"))
        assertTrue(ConfigLayer.APP_CONFIG in changed)
        assertTrue(ConfigLayer.THEME in changed)
        assertTrue(ConfigLayer.HOME_LAYOUT in changed)
        assertTrue(ConfigLayer.STRINGS in changed)
        assertEquals(1, store.saveCount)
        assertEquals(4, store.load()?.theme?.version)

        val again = svc.refresh(listOf("ar"))
        assertEquals(emptySet<ConfigLayer>(), again)
        assertEquals(1, store.saveCount)
    }

    @Test
    fun `malformed layer leaves other layers applied`() = runTest {
        val store = InMemoryStore()
        val responses = fullResponses().apply { this["v1/config/theme"] = "{not json" }
        val svc = service(store, StubClient(responses))

        val changed = svc.refresh(listOf("ar"))
        assertFalse(ConfigLayer.THEME in changed)
        assertTrue(ConfigLayer.APP_CONFIG in changed)
        assertNull(store.load()?.theme)
        assertTrue(store.load()?.appConfig != null)
    }

    @Test
    fun `up to date string pack leaves overlay unchanged`() = runTest {
        val cached = ConfigSnapshot(
            stringPacks = mapOf(
                "ar" to com.fatwabot.core.common.StringPack("ar", 7, mapOf("k" to "قيمة")),
            ),
            fetchedAtEpochSeconds = 0,
        )
        // strings endpoint returns up_to_date marker
        val client = StubClient(mutableMapOf("v1/config/strings/ar" to """{"up_to_date": true}"""))
        val svc = service(InMemoryStore(cached), client)
        svc.refresh(listOf("ar"))
        assertEquals("قيمة", svc.string("k", "ar"))
    }

    @Test
    fun `flag gating honors min app version`() = runTest {
        val svc = service(InMemoryStore(), StubClient(fullResponses()))
        svc.refresh(emptyList())
        assertTrue(svc.isEnabled("module.prayer", "0.1.0"))
        assertFalse(svc.isEnabled("module.ai_ask", "1.9.9"))
        assertTrue(svc.isEnabled("module.ai_ask", "2.0.1"))
        assertFalse(svc.isEnabled("module.nope", "9.9.9"))
    }

    @Test
    fun `semver comparisons`() {
        assertTrue(SemVer.isVersionAtLeast("1.2.10", "1.2.9"))
        assertTrue(SemVer.isVersionAtLeast("1.2", "1.2.0"))
        assertFalse(SemVer.isVersionAtLeast("1.2.0", "1.10"))
        assertTrue(SemVer.isVersionAtLeast("2.0.0", "2"))
    }
}
