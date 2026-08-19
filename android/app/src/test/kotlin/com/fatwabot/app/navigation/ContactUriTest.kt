package com.fatwabot.app.navigation

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * The contact values come from the dashboard, so what an operator types is not
 * under our control: bare handles, pasted URLs, and phone numbers with spaces
 * and a leading "+" all have to land on the right app.
 */
class ContactUriTest {

    @Test
    fun `bare values become the channel's canonical url`() {
        assertEquals("mailto:info@example.com", contactUri(ContactChannel.EMAIL, "info@example.com"))
        assertEquals("https://wa.me/201001234567", contactUri(ContactChannel.WHATSAPP, "+20 100 123 4567"))
        assertEquals("https://instagram.com/fatwa", contactUri(ContactChannel.INSTAGRAM, "@fatwa"))
        assertEquals("https://x.com/fatwa", contactUri(ContactChannel.X, "fatwa"))
    }

    @Test
    fun `a pasted url is used as given`() {
        assertEquals(
            "https://instagram.com/some.account",
            contactUri(ContactChannel.INSTAGRAM, " https://instagram.com/some.account "),
        )
        assertEquals("mailto:info@example.com", contactUri(ContactChannel.EMAIL, "mailto:info@example.com"))
        assertEquals("https://chat.whatsapp.com/abc", contactUri(ContactChannel.WHATSAPP, "https://chat.whatsapp.com/abc"))
    }

    @Test
    fun `nothing usable yields no url`() {
        assertNull(contactUri(ContactChannel.EMAIL, "   "))
        assertNull(contactUri(ContactChannel.WHATSAPP, "call us"))
    }
}
