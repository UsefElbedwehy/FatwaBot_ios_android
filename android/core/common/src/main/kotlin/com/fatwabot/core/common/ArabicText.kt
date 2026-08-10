package com.fatwabot.core.common

/**
 * Expands Arabic honorific ligatures that most shipped fonts cannot draw.
 * Mirror of iOS `ArabicHonorifics`.
 *
 * ## Why this is not a font problem to fix with a font
 * The بلوغ المرام corpus uses two generations of ligature. `ﷺ` (U+FDFA) dates
 * from Unicode 1.1 and every Arabic font on iOS and Android draws it. The
 * honorifics in the U+FD40–FD4F block were added in **Unicode 14 (2021)**, and
 * the system Arabic fonts on shipping devices predate them — so 1,176
 * occurrences across بلوغ المرام alone rendered as ▯ boxes.
 *
 * Bundling a font with that coverage would mean shipping several MB, picking a
 * licence, and still leaving older OS versions and every *widget* — which uses
 * system fonts — broken. Expanding the ligature to the words it stands for
 * renders correctly in every font, on every OS version, at every size, forever.
 * The meaning is identical: these codepoints exist purely as a typographic
 * contraction of the phrase.
 *
 * Expansions are taken from each codepoint's own Unicode name (e.g. U+FD41
 * ARABIC LIGATURE RADI ALLAAHU ANH → رضي الله عنه), not from judgement — these
 * are religious honorifics and an invented expansion would be a meaning error.
 *
 * `ﷺ` and `ﷻ` are deliberately left alone: they render, and the ligature is the
 * form readers expect.
 */
object ArabicHonorifics {

    /** U+FD40–FD4F and U+FDFF, keyed by character. */
    internal val expansions: Map<Char, String> = mapOf(
        '﵀' to "رحمه الله", // RAHIMAHU ALLAAH
        '﵁' to "رضي الله عنه", // RADI ALLAAHU ANH
        '﵂' to "رضي الله عنها", // RADI ALLAAHU ANHAA
        '﵃' to "رضي الله عنهم", // RADI ALLAAHU ANHUM
        '﵄' to "رضي الله عنهما", // RADI ALLAAHU ANHUMAA
        '﵅' to "رضي الله عنهن", // RADI ALLAAHU ANHUNNA
        '﵆' to "صلى الله عليه وآله", // SALLALLAAHU ALAYHI WA-AALIH
        '﵇' to "عليه السلام", // ALAYHI AS-SALAAM
        '﵈' to "عليهم السلام", // ALAYHIM AS-SALAAM
        '﵉' to "عليهما السلام", // ALAYHIMAA AS-SALAAM
        '﵊' to "عليه الصلاة والسلام", // ALAYHI AS-SALAATU WAS-SALAAM
        '﵋' to "قدس سره", // QUDDISA SIRRAH
        '﵌' to "صلى الله عليه وآله وسلم", // SALLALLAHU ALAYHI WAAALIHEE WA-SALLAM
        '﵍' to "عليها السلام", // ALAYHAA AS-SALAAM
        '﵎' to "تبارك وتعالى", // TABAARAKA WA-TAAALAA
        '﵏' to "رحمهم الله", // RAHIMAHUM ALLAAH
        '﷿' to "عز وجل", // AZZA WA JALL
    )

    /**
     * Returns [text] with unrenderable honorific ligatures expanded.
     *
     * A no-op for text containing none, which is the overwhelming majority of
     * strings the app draws.
     */
    fun expanded(text: String): String {
        if (text.none { expansions.containsKey(it) }) return text
        return buildString(text.length) {
            for (character in text) {
                val expansion = expansions[character]
                if (expansion == null) {
                    append(character)
                } else {
                    // The source writes the ligature tight against the preceding
                    // word ("أَبِي أَيُّوبَ﵁"); the expansion is words, so it needs
                    // the space the glyph implied.
                    if (isNotEmpty() && !last().isWhitespace()) append(' ')
                    append(expansion)
                }
            }
        }
    }
}

/**
 * Display form of Arabic content: honorific ligatures expanded to the words they
 * stand for, so they render in fonts that lack the Unicode 14 glyphs.
 */
val String.expandingArabicHonorifics: String
    get() = ArabicHonorifics.expanded(this)

/** Display helpers for hadith text whose takhrij now lives in its own field. */
object HadithDisplay {

    /**
     * The matn with its trailing takhrij removed, when the grading is exactly
     * that trailing clause. Mirror of iOS `HadithDisplay.matnWithoutTakhrij`.
     *
     * Migration 0029 **copied** the takhrij into `grading` rather than moving
     * it, so the stored matn still ends with the attribution. iOS has trimmed it
     * since; Android never did, and rendered `arabicText` raw — so every hadith
     * on Android showed its attribution twice, once trailing the text and again
     * as the grading label.
     *
     * Trimming here rather than in the database keeps that decision intact: the
     * stored text stays as printed, and a bad trim is a display bug rather than
     * lost scripture.
     *
     * Only a **suffix** is removed. Some entries carry the takhrij mid-text
     * followed by ibn Hajr's commentary; cutting there would leave a hole in the
     * sentence, so those are returned untouched and simply show the clause twice
     * — the safe failure.
     *
     * Returns the matn unchanged when [grading] is empty, is not the trailing
     * clause (العمدة's stamped "متفق عليه." appears nowhere in its matn), or when
     * removing it would leave nothing to read.
     */
    fun matnWithoutTakhrij(matn: String, grading: String): String {
        val text = matn.normalizedWhitespace()
        val clause = grading.normalizedWhitespace()
        if (clause.isEmpty() || !text.endsWith(clause)) return text

        val remainder = text.dropLast(clause.length).trim()
        // A hadith that is *only* its attribution has nothing left to show.
        // Tested by content rather than length: a legitimate short matn can be
        // very few characters once harakat are discounted, and a length
        // threshold rejects it.
        if (remainder.none { it.isLetter() }) return text
        return remainder
    }

    /** Collapses every run of whitespace to a single space, and trims. */
    private fun String.normalizedWhitespace(): String =
        split(Regex("\\s+")).filter { it.isNotEmpty() }.joinToString(" ")
}
