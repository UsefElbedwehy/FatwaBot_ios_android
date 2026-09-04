package com.fatwabot.core.designsystem

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp

private fun List<InlineSpan>.toAnnotated(): AnnotatedString = buildAnnotatedString {
    for (span in this@toAnnotated) {
        if (!span.bold && !span.italic) {
            append(span.text)
            continue
        }
        withStyle(
            SpanStyle(
                fontWeight = if (span.bold) FontWeight.Bold else null,
                fontStyle = if (span.italic) FontStyle.Italic else null,
            ),
        ) { append(span.text) }
    }
}

/**
 * Renders the Markdown subset the answer model emits (see [parseMarkdownBlocks]).
 *
 * Bullets get a "• " prefix inside the string rather than a Row with a separate
 * glyph, so the marker sits on the correct side automatically in both Arabic and
 * English — the text direction decides, not the layout.
 */
@Composable
fun MarkdownText(
    markdown: String,
    tokens: ColorTokens,
    modifier: Modifier = Modifier,
    textAlign: TextAlign = TextAlign.End,
) {
    val blocks = remember(markdown) { parseMarkdownBlocks(markdown) }
    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(10.dp)) {
        for (block in blocks) {
            when (block) {
                is MarkdownBlock.Heading -> Text(
                    block.spans.toAnnotated(),
                    // Only two visual weights: the model's headings are short
                    // labels ("الأدلة على الوجوب"), not a document outline, so
                    // six distinct levels would be noise.
                    style = if (block.level <= 2) {
                        MaterialTheme.typography.titleMedium
                    } else {
                        MaterialTheme.typography.titleSmall
                    },
                    fontWeight = FontWeight.SemiBold,
                    color = tokens.primary,
                    textAlign = textAlign,
                    modifier = Modifier.fillMaxWidth(),
                )
                is MarkdownBlock.Bullet -> Text(
                    buildAnnotatedString {
                        append("• ")
                        append(block.spans.toAnnotated())
                    },
                    style = MaterialTheme.typography.bodyLarge,
                    color = tokens.onSurface,
                    textAlign = textAlign,
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 4.dp),
                )
                is MarkdownBlock.Paragraph -> Text(
                    block.spans.toAnnotated(),
                    style = MaterialTheme.typography.bodyLarge,
                    color = tokens.onSurface,
                    textAlign = textAlign,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        }
    }
}
