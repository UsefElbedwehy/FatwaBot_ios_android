package com.fatwabot.feature.fatwasearch

import androidx.annotation.StringRes
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** The three entry points (docs/features/ai-search-m5.0-spec.md §Modes),
 * matching the reference app exactly — mirror of iOS FatwaSearchMode.
 * Declaration order is display order: the Home cards read fatwa · hadith ·
 * question in that order. */
enum class FatwaSearchMode(val wireValue: String) {
    FATWA("fatwa"),
    HADITH("hadith"),
    GENERAL("general"),
}

// Same wording as the app module's home_card_* strings (Home intent cards) —
// duplicated here because a feature module can't reference :app's resources
// (:app depends on this module, never the reverse). Keep both in sync.
@StringRes
fun FatwaSearchMode.titleRes(): Int = when (this) {
    FatwaSearchMode.FATWA -> R.string.fatwa_search_mode_fatwa
    FatwaSearchMode.HADITH -> R.string.fatwa_search_mode_hadith
    FatwaSearchMode.GENERAL -> R.string.fatwa_search_mode_general
}

@StringRes
fun FatwaSearchMode.placeholderRes(): Int = when (this) {
    FatwaSearchMode.FATWA -> R.string.fatwa_search_placeholder_fatwa
    FatwaSearchMode.HADITH -> R.string.fatwa_search_placeholder_hadith
    FatwaSearchMode.GENERAL -> R.string.fatwa_search_placeholder_general
}

@StringRes
fun FatwaSearchMode.hintRes(): Int = when (this) {
    FatwaSearchMode.FATWA -> R.string.fatwa_search_hint_fatwa
    FatwaSearchMode.HADITH -> R.string.fatwa_search_hint_hadith
    FatwaSearchMode.GENERAL -> R.string.fatwa_search_hint_general
}

@Serializable
internal data class SearchRequestBody(val question: String, val mode: String)

/** One verified citation backing an answer — server-enforced substring match
 * against the source chunk (never a fabricated quote; see backend
 * citation_verify.ts). */
@Serializable
data class SearchCitation(
    @SerialName("chunk_id") val chunkId: String,
    val scholar: String,
    @SerialName("source_title") val sourceTitle: String,
    @SerialName("page_number") val pageNumber: Int? = null,
    @SerialName("video_timestamp") val videoTimestamp: Int? = null,
    @SerialName("quoted_text") val quotedText: String,
)

@Serializable
data class SearchResponse(
    val answer: String,
    val citations: List<SearchCitation>,
    val refused: Boolean,
    val mode: String,
)
