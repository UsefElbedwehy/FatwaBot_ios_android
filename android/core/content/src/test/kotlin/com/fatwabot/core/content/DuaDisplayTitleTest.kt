package com.fatwabot.core.content

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** Mirrors the iOS `ContentModelsTests` — same rules, same fixtures. */
class DuaDisplayTitleTest {

    private fun dua(title: String, arabic: String) = Dua(
        id = "1", sortOrder = 0, title = title, arabicText = arabic, source = "حصن المسلم",
    )

    @Test
    fun `prefers a real title`() {
        assertEquals("دعاء الاستخارة", dua("دعاء الاستخارة", "اللهم إني أستخيرك").displayTitle)
    }

    /** Every du'a in the imported Hisn al-Muslim library has an empty title. */
    @Test
    fun `falls back to the opening words`() {
        val d = dua("", "((سُبْحَانَ اللَّهِ وَبِحَمْدِهِ)) (مائة مرَّةٍ).")
        assertFalse(d.displayTitle.isEmpty())
        assertFalse("recitation marks must be stripped", d.displayTitle.startsWith("("))
        assertTrue(d.displayTitle.startsWith("سُبْحَانَ"))
    }

    @Test
    fun `treats a whitespace-only title as empty`() {
        assertEquals("الحمد لله", dua("   ", "الحمد لله").displayTitle)
    }

    @Test
    fun `truncates a long snippet on a word boundary`() {
        val snippet = dua("", "كلمة ".repeat(40)).displayTitle
        assertTrue(snippet.endsWith("…"))
        assertTrue(snippet.length <= 49)
        assertFalse("should not end on a dangling space", snippet.dropLast(1).endsWith(" "))
    }
}
