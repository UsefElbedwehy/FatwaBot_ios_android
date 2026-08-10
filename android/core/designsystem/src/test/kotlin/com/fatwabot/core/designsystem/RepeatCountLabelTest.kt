package com.fatwabot.core.designsystem

import java.util.Locale
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Arabic pluralisation of the repeat marker — mirror of iOS
 * `RepeatCountLabelTests`, case for case, because two hand-rolled plural tables
 * that are not tested against the same inputs will drift.
 *
 * Tested rather than eyeballed: the rule is not the English one, and the wrong
 * output is grammatically broken text shown on scripture. The naive
 * `"$count مرة"` produces "3 مرة", and the rule that catches people out is that
 * counts above ten revert to the singular — ١٠٠ مرة, not ١٠٠ مرات.
 */
class RepeatCountLabelTest {

    private val arabic = Locale("ar")

    @Test
    fun `one is suppressed`() {
        // Every dhikr is said at least once; a marker saying so on every card is
        // noise that pushes the matn down.
        assertNull(RepeatCountLabel.text(1, arabic))
    }

    @Test
    fun `zero and negative are suppressed`() {
        assertNull(RepeatCountLabel.text(0, arabic))
        assertNull(RepeatCountLabel.text(-3, arabic))
    }

    @Test
    fun `two uses the dual and drops the numeral`() {
        // Arabic has a dual form; "مرتان" already means "twice", so printing
        // "2 مرتان" would say two twice.
        assertEquals("مرتان", RepeatCountLabel.text(2, arabic))
    }

    @Test
    fun `three through ten use the plural`() {
        assertEquals("3 مرات", RepeatCountLabel.text(3, arabic))
        assertEquals("7 مرات", RepeatCountLabel.text(7, arabic))
        assertEquals("10 مرات", RepeatCountLabel.text(10, arabic))
    }

    /** The counts this actually protects: 33 after prayer, 100 for istighfar. */
    @Test
    fun `eleven and above revert to the singular`() {
        assertEquals("11 مرة", RepeatCountLabel.text(11, arabic))
        assertEquals("33 مرة", RepeatCountLabel.text(33, arabic))
        assertEquals("100 مرة", RepeatCountLabel.text(100, arabic))
    }

    @Test
    fun `non-arabic locales use the compact marker`() {
        assertEquals("×3", RepeatCountLabel.text(3, Locale.ENGLISH))
        assertEquals("×2", RepeatCountLabel.text(2, Locale.US))
        assertNull(RepeatCountLabel.text(1, Locale.ENGLISH))
    }

    /** Regional Arabic is still Arabic — the check is on language, not identifier. */
    @Test
    fun `regional arabic variants are still arabic`() {
        assertEquals("3 مرات", RepeatCountLabel.text(3, Locale("ar", "EG")))
        assertEquals("3 مرات", RepeatCountLabel.text(3, Locale("ar", "SA")))
    }
}
