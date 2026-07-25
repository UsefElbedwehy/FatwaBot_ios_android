package com.fatwabot.core.common

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * The widget→app hand-off fails *silently* when it breaks — the tap just opens
 * Home and nobody notices — so the parsing side is worth pinning down. Mirrors
 * the iOS CoreKitTests/DeepLinkTests suite.
 */
class DeepLinkTest {
    @Test
    fun `every entry round-trips through its uri string`() {
        DeepLink.entries.forEach { link ->
            assertEquals(link, DeepLink.parse("${DeepLink.SCHEME}://${link.host}"))
        }
    }

    @Test
    fun `parses authority form`() {
        assertEquals(DeepLink.DUA, DeepLink.parse("fatwabot://dua"))
        assertEquals(DeepLink.PRAYER, DeepLink.parse("fatwabot://prayer"))
        assertEquals(DeepLink.JOURNEY, DeepLink.parse("fatwabot://journey"))
    }

    /** Empty authority + path — accepted so a slightly malformed link still lands. */
    @Test
    fun `parses path-only form`() {
        assertEquals(DeepLink.DUA, DeepLink.parse("fatwabot:///dua"))
    }

    @Test
    fun `scheme and host are case insensitive`() {
        assertEquals(DeepLink.DUA, DeepLink.parse("FATWABOT://DUA"))
    }

    @Test
    fun `ignores query and fragment`() {
        assertEquals(DeepLink.DUA, DeepLink.parse("fatwabot://dua?from=widget"))
        assertEquals(DeepLink.DUA, DeepLink.parse("fatwabot://dua#top"))
    }

    @Test
    fun `rejects foreign schemes`() {
        assertNull(DeepLink.parse("https://fatwabot.app/dua"))
        assertNull(DeepLink.parse("otherapp://dua"))
    }

    @Test
    fun `rejects unknown or empty routes`() {
        assertNull(DeepLink.parse("fatwabot://leaderboard"))
        assertNull(DeepLink.parse("fatwabot://"))
        assertNull(DeepLink.parse(""))
        assertNull(DeepLink.parse(null))
    }

    /** Keep in sync with the AndroidManifest intent-filter and iOS DeepLink. */
    @Test
    fun `scheme is stable`() {
        assertEquals("fatwabot", DeepLink.SCHEME)
    }
}
