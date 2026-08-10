package com.fatwabot.core.common

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Mirror of the iOS `ArabicHonorificsTests` / `HadithDisplayTests`. These two
 * helpers existed only on iOS until now — Android rendered `arabicText` raw,
 * which is why every hadith showed its attribution twice and why the Unicode 14
 * honorifics drew as ▯ boxes.
 */
class ArabicTextTest {

    // MARK: - Honorific expansion

    @Test
    fun `text without honorifics is returned untouched`() {
        val plain = "الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ"
        assertEquals(plain, plain.expandingArabicHonorifics)
    }

    @Test
    fun `radi allaahu anh expands to its words`() {
        assertEquals("عن أبي هريرة رضي الله عنه", "عن أبي هريرة ﵁".expandingArabicHonorifics)
    }

    /**
     * The corpus writes the ligature tight against the preceding word, with no
     * space — the glyph implied one. Expanding without reinstating it would run
     * two words together.
     */
    @Test
    fun `a space is inserted when the ligature is glued to the previous word`() {
        assertEquals("أَبِي أَيُّوبَ رضي الله عنه", "أَبِي أَيُّوبَ﵁".expandingArabicHonorifics)
    }

    @Test
    fun `an existing space is not doubled`() {
        assertEquals("أَبِي أَيُّوبَ رضي الله عنه", "أَبِي أَيُّوبَ ﵁".expandingArabicHonorifics)
    }

    @Test
    fun `several honorifics in one passage all expand`() {
        assertEquals(
            "رضي الله عنه ثم رحمه الله ثم عز وجل",
            "﵁ ثم ﵀ ثم ﷿".expandingArabicHonorifics,
        )
    }

    /**
     * U+FDFA (ﷺ) and U+FDFB (ﷻ) date from Unicode 1.1, render everywhere, and are
     * the form readers expect. Expanding them would be a regression.
     */
    @Test
    fun `the widely supported ligatures are left alone`() {
        assertEquals("قال النبي ﷺ", "قال النبي ﷺ".expandingArabicHonorifics)
        assertEquals("الله ﷻ", "الله ﷻ".expandingArabicHonorifics)
    }

    @Test
    fun `every mapped codepoint expands to something non-empty`() {
        for ((character, expansion) in ArabicHonorifics.expansions) {
            assertEquals(
                "U+%04X must expand".format(character.code),
                expansion,
                character.toString().expandingArabicHonorifics.trim(),
            )
        }
    }

    // MARK: - Takhrij

    @Test
    fun `a trailing takhrij matching the grading is removed`() {
        assertEquals(
            "إنما الأعمال بالنيات",
            HadithDisplay.matnWithoutTakhrij(
                "إنما الأعمال بالنيات متفق عليه.",
                "متفق عليه.",
            ),
        )
    }

    @Test
    fun `an empty grading leaves the matn alone`() {
        val matn = "إنما الأعمال بالنيات متفق عليه."
        assertEquals(matn, HadithDisplay.matnWithoutTakhrij(matn, ""))
    }

    /**
     * العمدة stamps "متفق عليه." on every entry as a grading, but its matn does
     * not carry the clause. Nothing must be cut in that case.
     */
    @Test
    fun `a grading that is not the trailing clause leaves the matn alone`() {
        val matn = "إنما الأعمال بالنيات"
        assertEquals(matn, HadithDisplay.matnWithoutTakhrij(matn, "متفق عليه."))
    }

    /**
     * Some entries carry the takhrij mid-text followed by ibn Hajr's commentary.
     * Cutting there would leave a hole in the sentence, so those are returned
     * untouched and show the clause twice — the safe failure.
     */
    @Test
    fun `a takhrij in the middle of the text is not cut out`() {
        val matn = "إنما الأعمال بالنيات متفق عليه. وزاد ابن حجر تعليقًا"
        assertEquals(matn, HadithDisplay.matnWithoutTakhrij(matn, "متفق عليه."))
    }

    @Test
    fun `a matn that is only its attribution is left readable`() {
        assertEquals(
            "متفق عليه.",
            HadithDisplay.matnWithoutTakhrij("متفق عليه.", "متفق عليه."),
        )
    }

    @Test
    fun `whitespace differences between matn and grading still match`() {
        assertEquals(
            "إنما الأعمال بالنيات",
            HadithDisplay.matnWithoutTakhrij(
                "إنما   الأعمال بالنيات\n\nمتفق  عليه.",
                " متفق عليه. ",
            ),
        )
    }
}
