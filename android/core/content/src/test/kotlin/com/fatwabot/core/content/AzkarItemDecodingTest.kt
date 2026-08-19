package com.fatwabot.core.content

import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** Mirrors the iOS `AzkarItem` decoding guarantees. */
class AzkarItemDecodingTest {
    private val json = Json { ignoreUnknownKeys = true }

    @Test
    fun `decodes a payload written before titles existed`() {
        // Every install holds a cached azkar payload from before this field
        // existed. Without the default this throws, the whole collection is
        // rejected, and the reader silently falls back to bundled seed with
        // nothing anywhere saying why.
        val payload = """
            {"id":"a","sortOrder":0,"arabicText":"سبحان الله",
             "source":"صحيح البخاري","repeatCount":1}
        """.trimIndent()
        val item = json.decodeFromString(AzkarItem.serializer(), payload)
        assertEquals("a", item.id)
        assertNull(item.title)
    }

    @Test
    fun `decodes a title when the server sends one`() {
        val payload = """
            {"id":"a","sortOrder":0,"arabicText":"سبحان الله","title":"التسبيح",
             "source":"صحيح البخاري","repeatCount":1}
        """.trimIndent()
        assertEquals("التسبيح", json.decodeFromString(AzkarItem.serializer(), payload).title)
    }
}
