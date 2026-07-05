package com.fatwabot.core.content

import com.fatwabot.core.network.ApiClientProtocol
import com.fatwabot.core.network.ApiException
import java.nio.file.Files
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Mirrors iOS ContentServiceTests — the four spec cases from content-pipeline.md. */
class ContentServiceTest {

    private class StubClient(val responses: MutableMap<String, String> = mutableMapOf()) : ApiClientProtocol {
        override suspend fun getRaw(path: String, query: Map<String, String>): String =
            responses[path] ?: throw ApiException.Transport("stubbed failure for $path")
    }

    private fun tempStore() = ContentFileStore(Files.createTempDirectory("content-test").toFile())

    @Test
    fun `first launch offline renders bundled seed`() = runTest {
        val service = ContentService(tempStore(), StubClient())
        val azkar = service.azkar("ar")
        assertNotNull("bundled seed must render with zero network", azkar)
        assertTrue(azkar!!.categories.isNotEmpty())
        assertEquals("morning", azkar.categories.first().slug)

        assertTrue(service.duas("ar")!!.categories.isNotEmpty())
        assertTrue(service.hadithCollections("ar").isNotEmpty())
        assertTrue(service.wirdTemplates("ar")!!.templates.isNotEmpty())
    }

    @Test
    fun `refresh applies newer version and persists`() = runTest {
        val store = tempStore()
        val client = StubClient()
        client.responses["v1/content/azkar"] =
            """{"version": 999, "categories": [{"id":"x","slug":"test","name":"Test","sortOrder":0,"items":[]}]}"""
        val service = ContentService(store, client)

        val changed = service.refreshAzkar("ar")
        assertTrue(changed)
        assertEquals(999, service.azkar("ar")?.version)

        val reloaded = ContentService(store, StubClient())
        assertEquals(999, reloaded.azkar("ar")?.version)
    }

    @Test
    fun `refresh with unchanged version reports no change`() = runTest {
        val client = StubClient()
        client.responses["v1/content/azkar"] = """{"version": 1, "categories": []}"""
        val service = ContentService(tempStore(), client)

        service.refreshAzkar("ar")
        val second = service.refreshAzkar("ar")
        assertFalse("identical payload should report no change", second)
    }

    @Test
    fun `malformed response leaves cache untouched`() = runTest {
        val client = StubClient()
        client.responses["v1/content/azkar"] = "{not json"
        val service = ContentService(tempStore(), client)

        val before = service.azkar("ar")
        val changed = service.refreshAzkar("ar")
        val after = service.azkar("ar")

        assertFalse(changed)
        assertEquals("malformed refresh must not corrupt or clear the cache", before, after)
    }

    @Test
    fun `locale switch does not cross contaminate`() = runTest {
        val client = StubClient()
        client.responses["v1/content/azkar"] =
            """{"version": 5, "categories": [{"id":"en-cat","slug":"s","name":"English","sortOrder":0,"items":[]}]}"""
        val service = ContentService(tempStore(), client)

        service.refreshAzkar("en")
        val en = service.azkar("en")
        val ar = service.azkar("ar")

        assertEquals(5, en?.version)
        assertNotEquals(5, ar?.version)
        assertEquals("ar cache must be unaffected by an en refresh", "morning", ar?.categories?.first()?.slug)
    }
}
