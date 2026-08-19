package com.fatwabot.core.content

import kotlinx.serialization.Serializable

// Mirror of backend/functions/api/content_types.ts and iOS ContentKit's
// ContentModels.swift — already locale-resolved plain strings; property
// names match JSON keys exactly (server + bundled seed share one shape).

@Serializable
data class AzkarItem(
    val id: String,
    val sortOrder: Int,
    val arabicText: String,
    /**
     * Short name for the dhikr ("شكر الله على رد الروح"), when one exists.
     *
     * Nullable and defaulted, and expected to stay that way: titling the corpus
     * is reviewed religious content that lands separately from this plumbing, so
     * the reader must render an untitled entry correctly indefinitely. The
     * default also means a cached payload written before this field existed
     * still deserializes instead of taking the whole collection down.
     */
    val title: String? = null,
    val transliteration: String? = null,
    val translation: String? = null,
    val virtueNote: String? = null,
    val source: String,
    val repeatCount: Int,
)

@Serializable
data class AzkarCategory(
    val id: String,
    val slug: String,
    val name: String,
    val sortOrder: Int,
    val items: List<AzkarItem>,
)

@Serializable
data class AzkarCollection(val version: Int, val categories: List<AzkarCategory>)

@Serializable
data class Dua(
    val id: String,
    val sortOrder: Int,
    val title: String,
    val arabicText: String,
    val transliteration: String? = null,
    val translation: String? = null,
    val source: String,
) {
    /**
     * What to show as the row's heading — mirror of iOS `Dua.displayTitle`.
     *
     * Hisn al-Muslim — the source of the whole imported library — titles its
     * *chapters*, not its individual supplications, so every `title` comes back
     * empty. Rendering the raw field left every row in the library showing
     * nothing but "حصن المسلم", one identical line 132 categories deep.
     *
     * The opening words of the du'a are how these are actually referred to, so
     * they make a better heading than a placeholder. Truncation is on a word
     * boundary to avoid cutting an Arabic word in half.
     */
    val displayTitle: String
        get() = title.trim().ifEmpty { snippet(arabicText) }

    companion object {
        internal fun snippet(text: String, limit: Int = 48): String {
            // Strip the recitation marks the corpus wraps verses in, so a
            // snippet starts on the words themselves rather than punctuation.
            val cleaned = text
                .replace("((", "").replace("))", "")
                .replace("﴿", "").replace("﴾", "")
                .trim()
            if (cleaned.length <= limit) return cleaned
            val prefix = cleaned.take(limit)
            val lastSpace = prefix.lastIndexOf(' ')
            return if (lastSpace <= 0) "$prefix…" else prefix.substring(0, lastSpace) + "…"
        }
    }
}

@Serializable
data class DuaCategory(
    val id: String,
    val slug: String,
    val name: String,
    val sortOrder: Int,
    val duas: List<Dua>,
)

@Serializable
data class DuaCollection(val version: Int, val categories: List<DuaCategory>)

@Serializable
data class HadithCollectionSummary(
    val id: String,
    val slug: String,
    val name: String,
    val description: String,
    val entryCount: Int,
)

@Serializable
data class HadithCollectionsResponse(val collections: List<HadithCollectionSummary>)

@Serializable
data class HadithEntry(
    val id: String,
    val number: Int,
    val arabicText: String,
    val translation: String? = null,
    val grading: String,
    val benefitNote: String? = null,
    val source: String,
)

@Serializable
data class HadithCollectionDetail(
    val version: Int,
    val slug: String,
    val name: String,
    val description: String,
    val entries: List<HadithEntry>,
)

@Serializable
data class WirdTemplate(
    val id: String,
    val name: String,
    val description: String,
    val type: String,
    val defaultTarget: Int,
    val defaultUnit: String,
    val defaultFrequency: String,
)

@Serializable
data class WirdTemplatesCollection(val version: Int, val templates: List<WirdTemplate>)
