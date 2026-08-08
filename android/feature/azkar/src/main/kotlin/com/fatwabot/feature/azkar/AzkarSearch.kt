package com.fatwabot.feature.azkar

import com.fatwabot.core.content.AzkarItem

/**
 * Matching for the azkar browse screen. Mirror of iOS `AzkarSearch`.
 *
 * Separate from the composable because the interesting part is not the layout:
 * Arabic matching is subtle enough to get wrong silently, and a filter that
 * quietly matches nothing looks identical to a category that is genuinely empty.
 */
object AzkarSearch {

    /**
     * Entries matching [query], or all of them when it is blank.
     *
     * Matches title, matn and source. Matn is included deliberately despite
     * being the least pleasant field to match on: until the corpus is titled it
     * is the only thing most entries can be found by, and a search returning
     * nothing for an untitled library reads as broken.
     */
    fun filter(items: List<AzkarItem>, query: String): List<AzkarItem> {
        val needle = folded(query.trim())
        if (needle.isEmpty()) return items
        return items.filter { item ->
            listOfNotNull(item.title, item.arabicText, item.source)
                .any { folded(it).contains(needle) }
        }
    }

    /**
     * Comparable form: combining marks dropped, lowercased, and alif/ya/ta-marbuta
     * variants unified.
     *
     * ## Why marks are stripped by codepoint category
     * The corpus is fully vowelled, so "الحمد" as typed shares almost no
     * codepoints with the stored "الْحَمْدُ" — every harakah is a character that
     * would otherwise have to match exactly. iOS learned this the hard way:
     * Foundation's `diacriticInsensitive` folding is built for Latin accents and
     * leaves Arabic harakat untouched, so relying on it made every query match
     * nothing. Doing it by Unicode category avoids the same trap here.
     *
     * ## Why alif and ya folding is separate
     * `أ إ آ ٱ` and `ا` are distinct *base letters*, as are `ى ي ی` — no amount
     * of mark-stripping unifies them. Hamza placement is exactly what people omit
     * when typing, so this is the difference between a search that works and one
     * that only works for careful typists.
     */
    internal fun folded(text: String): String {
        val builder = StringBuilder(text.length)
        for (character in text.lowercase()) {
            // Mn/Me/Mc — the harakat live here.
            when (Character.getType(character)) {
                Character.NON_SPACING_MARK.toInt(),
                Character.ENCLOSING_MARK.toInt(),
                Character.COMBINING_SPACING_MARK.toInt(),
                -> continue
            }
            builder.append(
                when (character) {
                    'أ', 'إ', 'آ', 'ٱ', 'ا' -> 'ا'
                    'ى', 'ي', 'ی' -> 'ي'
                    'ة', 'ه' -> 'ه'
                    else -> character
                },
            )
        }
        return builder.toString()
    }
}
