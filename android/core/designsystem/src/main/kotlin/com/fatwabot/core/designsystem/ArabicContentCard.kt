package com.fatwabot.core.designsystem

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.fatwabot.core.common.expandingArabicHonorifics
import java.util.Locale

/**
 * The repeat marker on a content card — "٣ مرات" rather than a bare "×3".
 * Mirror of iOS `RepeatCountLabel`.
 *
 * Arabic does not pluralise like English. Writing `"$count مرة"` produces
 * "3 مرة", which is simply wrong; the noun changes form with the count:
 *
 * - 1 → مرة (singular)
 * - 2 → مرتان (the dual — Arabic has one, distinct from the plural)
 * - 3…10 → مرات (plural)
 * - 11+ → مرة (reverts to the singular after ten)
 *
 * That last rule is the one that surprises people: ١٠٠ مرة, not ١٠٠ مرات. It
 * matters here because 33 and 100 are common counts in the corpus.
 *
 * Hand-rolled rather than an Android `<plurals>` resource on purpose: the rule
 * has to match iOS exactly, and two independent CLDR-ish tables drift. This one
 * is unit-tested against the same cases as its Swift counterpart.
 */
object RepeatCountLabel {

    /**
     * The marker for [count], or `null` when there is nothing worth showing.
     *
     * A count of one returns `null` deliberately: every dhikr is said at least
     * once, so "١ مرة" on most cards is noise that pushes the matn down. The
     * marker earns its place only when the count is a genuine instruction.
     */
    fun text(count: Int, locale: Locale = Locale.getDefault()): String? {
        if (count <= 1) return null
        if (locale.language != "ar") return "×$count"

        return when {
            // The dual carries the count itself — "2 مرتان" would say two twice.
            count == 2 -> "مرتان"
            count in 3..10 -> "$count مرات"
            else -> "$count مرة"
        }
    }
}

/**
 * One passage of Arabic scripture presented for reading: a short label, an
 * optional marker, the text itself, and a copy affordance. Mirror of iOS
 * `ArabicContentCard`.
 *
 * ## Why this is shared rather than written per feature
 * Azkar, Du'a and Hadith had three different presentations of the same thing —
 * a card list, a row-plus-detail-page, and a one-at-a-time reader with
 * prev/next. Each had grown its own subtitle, translation block, source line and
 * note card, so the same dua looked like different content depending on which
 * screen you reached it from, and every card carried more apparatus than
 * scripture.
 *
 * The owner's direction was explicit: show the passage, not the apparatus. One
 * component is the only way that stays true — a translation block added back to
 * "just" the hadith screen is how the drift started the first time.
 *
 * ## What is deliberately absent
 * No translation, transliteration, takhrij chain, virtue note or benefit note.
 * None of it is deleted from the API or the database; it is simply not on this
 * surface. Bringing any of it back is a product decision, not a styling one.
 *
 * @param label short heading — a dhikr title, a dua title, a hadith grading.
 *   Must be short: this is the reference design's "صحيح البخاري" slot, not
 *   somewhere to put a takhrij paragraph. The azkar corpus stores a 90–400
 *   character isnad chain in its `source` field, and passing that here would
 *   reproduce exactly the wall of text this component exists to remove.
 * @param badgeText short marker in the corner opposite the label, already
 *   formatted. Azkar puts a repeat instruction here (see [RepeatCountLabel]);
 *   Hadith puts the entry number.
 * @param accessory optional control alongside the copy button — Du'a hangs its
 *   favourite toggle here, so that removing that feature's detail page does not
 *   silently remove the feature with it.
 */
@Composable
fun ArabicContentCard(
    arabic: String,
    tokens: ColorTokens,
    modifier: Modifier = Modifier,
    label: String? = null,
    badgeText: String? = null,
    accessory: @Composable (() -> Unit)? = null,
) {
    val context = LocalContext.current
    val displayText = arabic.expandingArabicHonorifics
    // A whitespace-only title would otherwise draw a header band and a rule
    // above nothing.
    val trimmedLabel = label?.trim()?.takeIf { it.isNotEmpty() }

    BrandCard(tokens = tokens, contentPadding = 18.dp, modifier = modifier) {
        Column(
            horizontalAlignment = Alignment.End,
            verticalArrangement = Arrangement.spacedBy(12.dp),
            modifier = Modifier.fillMaxWidth(),
        ) {
            if (trimmedLabel != null || badgeText != null) {
                CardHeader(trimmedLabel, badgeText, tokens)
                HorizontalDivider(color = tokens.outline)
            }

            Text(
                text = displayText,
                color = tokens.onSurface,
                textAlign = TextAlign.End,
                // Amiri 21sp / 31sp leading, as on iOS. This was Roboto
                // `titleMedium` — 16sp with 24sp leading — so scripture was set
                // in the wrong face, 5sp small, with leading tight enough for
                // tashkīl to collide with the line above.
                style = ArabicScriptureStyle,
                modifier = Modifier.fillMaxWidth(),
            )

            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier.fillMaxWidth(),
            ) {
                Spacer(Modifier.weight(1f))
                accessory?.invoke()
                CopyChip(tokens) {
                    // What was on screen, not what was stored: the reader saw
                    // expanded honorifics, and pasting a ligature they never saw
                    // into an app that renders it as ▯ would be a surprise.
                    copyToClipboard(context, displayText)
                }
            }
        }
    }
}

/**
 * Label on the leading edge, marker on the trailing one. Under RTL Compose
 * mirrors this automatically, putting the label at the right and the marker at
 * the left — which is the reference layout.
 */
@Composable
private fun CardHeader(label: String?, badgeText: String?, tokens: ColorTokens) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.fillMaxWidth(),
    ) {
        if (label != null) {
            Text(
                text = label,
                color = tokens.onSurfaceSecondary,
                fontWeight = FontWeight.SemiBold,
                style = MaterialTheme.typography.titleSmall,
            )
        }
        Spacer(Modifier.weight(1f))
        if (badgeText != null) {
            Text(
                text = badgeText,
                color = tokens.primary,
                fontWeight = FontWeight.SemiBold,
                style = MaterialTheme.typography.labelMedium,
                modifier = Modifier
                    .clip(CircleShape)
                    .background(tokens.primaryContainer)
                    .padding(horizontal = 9.dp, vertical = 3.dp),
            )
        }
    }
}

@Composable
private fun CopyChip(tokens: ColorTokens, onClick: () -> Unit) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        modifier = Modifier
            .clip(CircleShape)
            .background(tokens.primary.copy(alpha = 0.10f))
            .clickable(onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 7.dp),
    ) {
        Icon(
            Icons.Filled.ContentCopy,
            contentDescription = null,
            tint = tokens.primary,
            modifier = Modifier.size(14.dp),
        )
        Text(
            text = stringResource(R.string.content_copy),
            color = tokens.primary,
            style = MaterialTheme.typography.labelMedium,
        )
    }
}

private fun copyToClipboard(context: Context, text: String) {
    val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
    clipboard?.setPrimaryClip(ClipData.newPlainText("dhikr", text))
}
