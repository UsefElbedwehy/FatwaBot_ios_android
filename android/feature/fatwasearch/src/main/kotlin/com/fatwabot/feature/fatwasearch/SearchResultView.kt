package com.fatwabot.feature.fatwasearch

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.MenuBook
import androidx.compose.material.icons.filled.Info
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.fatwabot.core.designsystem.ArabicContentCard
import com.fatwabot.core.designsystem.BrandCard
import com.fatwabot.core.designsystem.BrandSectionHeader
import com.fatwabot.core.designsystem.ColorTokens
import com.fatwabot.core.designsystem.MarkdownText
import com.fatwabot.core.designsystem.RulingDot
import com.fatwabot.core.designsystem.RulingStatus

/** The four status colours the client specified, folded from the API's
 *  five-fold scale. See [RulingStatus] for why واجب/مستحب share green. */
internal fun Ruling.status(): RulingStatus = when (this) {
    Ruling.WAJIB, Ruling.MUSTAHABB, Ruling.HALAL -> RulingStatus.PERMITTED
    Ruling.MUBAH -> RulingStatus.MUBAH
    Ruling.MAKRUH -> RulingStatus.MAKRUH
    Ruling.HARAM -> RulingStatus.HARAM
    Ruling.NONE -> RulingStatus.NONE
}

internal fun Ruling.labelRes(): Int? = when (this) {
    Ruling.WAJIB -> R.string.fatwa_search_ruling_wajib
    Ruling.MUSTAHABB -> R.string.fatwa_search_ruling_mustahabb
    Ruling.HALAL -> R.string.fatwa_search_ruling_halal
    Ruling.MUBAH -> R.string.fatwa_search_ruling_mubah
    Ruling.MAKRUH -> R.string.fatwa_search_ruling_makruh
    Ruling.HARAM -> R.string.fatwa_search_ruling_haram
    Ruling.NONE -> null
}

private fun resourceLabelRes(kind: String): Int = when (kind) {
    "video" -> R.string.fatwa_search_resource_video
    "website" -> R.string.fatwa_search_resource_website
    else -> R.string.fatwa_search_resource_book
}

/**
 * The M5.1 result: a summary carrying the ruling, a card per scholar with its
 * evidence, the sources, and the disclaimer the reference design ends on.
 *
 * Falls back gracefully in both directions. A response from a backend that
 * predates the structured contract has no summary and no scholar cards, so this
 * renders the flat `answer` exactly as before; and a structured response whose
 * scholar cards cover everything doesn't repeat `answer` underneath them.
 */
@Composable
internal fun SearchResultView(
    response: SearchResponse,
    isDark: Boolean,
    tokens: ColorTokens,
    onAskAgain: () -> Unit,
    onContact: () -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        if (response.summary != null) {
            SummaryCard(response, isDark, tokens)
        }

        // Hadith mode only. The schema allows these fields in any mode and the
        // model volunteers them when a fatwa happens to rest on a hadith —
        // which put a "نص الحديث / درجة الحديث" takhrij card inside a فتوى
        // answer, where it reads as the app having answered the wrong question.
        // Gated on the response's own mode rather than trusting the model to
        // withhold them.
        if (response.mode == FatwaSearchMode.HADITH.wireValue) {
            response.hadith?.let { HadithCard(it, tokens) }
        }

        response.scholarAnswers.forEach { ScholarCard(it, tokens) }

        // Only when the structured fields carried nothing — otherwise this is
        // the same words a second time, which is what the redesign set out to
        // stop.
        val renderedSomething = response.summary != null || response.scholarAnswers.isNotEmpty() ||
            (response.mode == FatwaSearchMode.HADITH.wireValue && response.hadith != null)
        if (!renderedSomething) {
            BrandCard(tokens = tokens) {
                MarkdownText(response.answer, tokens, Modifier.fillMaxWidth())
            }
        }

        if (response.resources.isNotEmpty()) {
            ResourceRow(response.resources, tokens)
        }

        if (response.citations.isNotEmpty()) {
            BrandSectionHeader(
                title = stringResource(R.string.fatwa_search_sources),
                icon = Icons.AutoMirrored.Filled.MenuBook,
                tokens = tokens,
            )
            response.citations.forEach { citation ->
                ArabicContentCard(
                    arabic = citation.quotedText,
                    tokens = tokens,
                    label = "${citation.sourceTitle} — ${citation.scholar}",
                    badgeText = citation.pageNumber?.let { stringResource(R.string.fatwa_search_page_badge, it) },
                )
            }
        }

        Button(
            onClick = onAskAgain,
            colors = ButtonDefaults.buttonColors(containerColor = tokens.primary, contentColor = tokens.onPrimary),
            shape = RoundedCornerShape(14.dp),
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text(stringResource(R.string.fatwa_search_new_search), fontWeight = FontWeight.SemiBold)
        }

        DisclaimerCard(tokens, onContact)
    }
}

/** Filled maroon, as the reference draws it — this is the one block a reader
 *  who reads nothing else will read, so it carries the ruling. */
@Composable
private fun SummaryCard(response: SearchResponse, isDark: Boolean, tokens: ColorTokens) {
    Surface(color = tokens.primary, shape = RoundedCornerShape(20.dp), modifier = Modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier.padding(18.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                RulingDot(response.ruling.status(), isDark)
                // The ruling is always named in text beside the dot. Colour
                // alone is invisible to a colour-blind or screen-reader user,
                // and this particular colour carries a fatwa.
                response.ruling.labelRes()?.let {
                    Text(
                        stringResource(it),
                        style = MaterialTheme.typography.labelLarge,
                        fontWeight = FontWeight.Bold,
                        color = tokens.onPrimary,
                    )
                }
                Text(
                    stringResource(R.string.fatwa_search_summary),
                    style = MaterialTheme.typography.labelMedium,
                    color = tokens.onPrimary.copy(alpha = 0.75f),
                )
            }
            MarkdownText(
                markdown = response.summary.orEmpty(),
                tokens = tokens.copy(onSurface = tokens.onPrimary, primary = tokens.onPrimary),
                modifier = Modifier.fillMaxWidth(),
            )
        }
    }
}

@Composable
private fun ScholarCard(answer: ScholarAnswer, tokens: ColorTokens) {
    BrandCard(tokens = tokens) {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
            Text(
                answer.scholar,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                color = tokens.primary,
                textAlign = TextAlign.End,
                modifier = Modifier.fillMaxWidth(),
            )
            MarkdownText(answer.answer, tokens, Modifier.fillMaxWidth())
            answer.evidence?.let { LabelledInset(stringResource(R.string.fatwa_search_evidence), it, tokens) }
        }
    }
}

@Composable
private fun HadithCard(hadith: HadithVerdict, tokens: ColorTokens) {
    BrandCard(tokens = tokens) {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.fillMaxWidth()) {
            LabelledInset(stringResource(R.string.fatwa_search_hadith_text), hadith.text, tokens)
            LabelledInset(stringResource(R.string.fatwa_search_hadith_grade), hadith.grade, tokens)
            hadith.source?.let { LabelledInset(stringResource(R.string.fatwa_search_hadith_source), it, tokens) }
            hadith.scholarVerdicts?.let {
                LabelledInset(stringResource(R.string.fatwa_search_hadith_verdicts), it, tokens)
            }
        }
    }
}

/** The reference's inset sub-card: a label, a maroon rule down the leading
 *  edge, and the text. Used for الدليل and for every hadith field. */
@Composable
private fun LabelledInset(label: String, body: String, tokens: ColorTokens) {
    Row(
        // Intrinsic-min height so the rule can fill the text's height instead of
        // guessing at one — it stays a rule beside the text at any font scale.
        modifier = Modifier.fillMaxWidth().height(IntrinsicSize.Min),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Box(
            modifier = Modifier
                .width(3.dp)
                .fillMaxHeight()
                .background(tokens.primary, RoundedCornerShape(2.dp)),
        )
        Column(verticalArrangement = Arrangement.spacedBy(4.dp), modifier = Modifier.fillMaxWidth()) {
            Text(
                label,
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.SemiBold,
                color = tokens.primary,
                textAlign = TextAlign.End,
                modifier = Modifier.fillMaxWidth(),
            )
            MarkdownText(body, tokens, Modifier.fillMaxWidth())
        }
    }
}

/** Availability chips. Every kind is shown, including the unavailable ones —
 *  "غير متاح" is information; an omitted row just leaves the reader wondering
 *  whether it was checked. */
@Composable
private fun ResourceRow(resources: List<SearchResource>, tokens: ColorTokens) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            stringResource(R.string.fatwa_search_available_on),
            style = MaterialTheme.typography.labelMedium,
            fontWeight = FontWeight.SemiBold,
            color = tokens.onSurfaceSecondary,
            textAlign = TextAlign.End,
            modifier = Modifier.fillMaxWidth(),
        )
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
            resources.forEach { resource ->
                Surface(
                    color = if (resource.available) tokens.primaryContainer else tokens.surfaceElevated,
                    shape = RoundedCornerShape(10.dp),
                ) {
                    Text(
                        text = if (resource.available) {
                            stringResource(resourceLabelRes(resource.kind))
                        } else {
                            "${stringResource(resourceLabelRes(resource.kind))} · ${
                                stringResource(R.string.fatwa_search_not_available)
                            }"
                        },
                        style = MaterialTheme.typography.labelSmall,
                        color = if (resource.available) tokens.primary else tokens.onSurfaceSecondary,
                        modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                    )
                }
            }
        }
    }
}

@Composable
private fun DisclaimerCard(tokens: ColorTokens, onContact: () -> Unit) {
    BrandCard(tokens = tokens) {
        Column(verticalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Icon(Icons.Filled.Info, contentDescription = null, tint = tokens.onSurfaceSecondary)
                Text(
                    stringResource(R.string.fatwa_search_disclaimer),
                    style = MaterialTheme.typography.bodySmall,
                    color = tokens.onSurfaceSecondary,
                    textAlign = TextAlign.End,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
            TextButton(onClick = onContact, modifier = Modifier.fillMaxWidth()) {
                Text(
                    stringResource(R.string.fatwa_search_contact_us),
                    color = tokens.primary,
                    fontWeight = FontWeight.SemiBold,
                )
            }
        }
    }
}
