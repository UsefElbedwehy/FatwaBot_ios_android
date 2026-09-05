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

/** The ruling behind the coloured status dot. The API emits the five-fold fiqh
 * scale so no information is lost server-side; the colour mapping is a
 * presentation decision made here.
 *
 * `NONE` is not "unknown" — it means the question has no ruling to give (a
 * hadith's grading, a du'a's wording), and no dot is drawn at all. Anything
 * unrecognised also lands here rather than throwing: a new ruling value added
 * server-side must never crash an older client. */
@Serializable
enum class Ruling {
    @SerialName("wajib")
    WAJIB,

    @SerialName("mustahabb")
    MUSTAHABB,

    @SerialName("halal")
    HALAL,

    @SerialName("mubah")
    MUBAH,

    @SerialName("makruh")
    MAKRUH,

    @SerialName("haram")
    HARAM,

    @SerialName("none")
    NONE,
}

/** One scholar's position, rendered as its own card. Citations are not nested
 * here — the API keeps them one flat list so verification can check them
 * exhaustively, and each names its scholar, so the UI groups by that. */
@Serializable
data class ScholarAnswer(
    val scholar: String,
    val answer: String,
    val evidence: String? = null,
)

/** Hadith mode's takhrij fields, laid out as separate rows. */
@Serializable
data class HadithVerdict(
    val text: String,
    val grade: String,
    val source: String? = null,
    @SerialName("scholar_verdicts") val scholarVerdicts: String? = null,
)

/** Where else this answer is available. Derived server-side from the verified
 * citations' sources — never from the model, which would happily claim a
 * YouTube link that doesn't exist. All kinds are always present so the UI can
 * say "غير متاح" rather than omit a row and leave the user unsure. */
@Serializable
data class SearchResource(
    val kind: String,
    val available: Boolean,
    val url: String? = null,
)

@Serializable
data class SearchResponse(
    val answer: String,
    val citations: List<SearchCitation>,
    val refused: Boolean,
    val mode: String,
    // Every structured field defaults, so a response from a backend that
    // predates M5.1 still decodes. The app degrades to the flat answer instead
    // of failing to parse.
    val summary: String? = null,
    val ruling: Ruling = Ruling.NONE,
    @SerialName("scholar_answers") val scholarAnswers: List<ScholarAnswer> = emptyList(),
    val hadith: HadithVerdict? = null,
    val resources: List<SearchResource> = emptyList(),
)
