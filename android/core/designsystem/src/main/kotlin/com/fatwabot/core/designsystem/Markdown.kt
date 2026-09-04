package com.fatwabot.core.designsystem

/**
 * A deliberately small Markdown subset — the one the answer model actually
 * emits: `**bold**`, `- ` / `* ` bullets, `#` headings, and blank-line
 * paragraph breaks.
 *
 * The answer was being rendered as plain text, so a heading arrived on screen
 * as a literal `**الحكم الراجح:**`, asterisks and all. A full CommonMark
 * dependency would parse tables, footnotes, HTML and reference links that never
 * appear in a fatwa answer, and would still need a Compose renderer written by
 * hand on top.
 *
 * Parsing is kept free of Compose types so it can be unit-tested directly —
 * see MarkdownTest — and the rendering half stays a thin mapping onto
 * `AnnotatedString`.
 *
 * Anything unrecognised is passed through as literal text. For scripture that
 * is the only safe default: dropping a character we failed to understand would
 * silently alter a quotation.
 */
sealed interface MarkdownBlock {
    data class Paragraph(val spans: List<InlineSpan>) : MarkdownBlock
    data class Bullet(val spans: List<InlineSpan>) : MarkdownBlock
    data class Heading(val level: Int, val spans: List<InlineSpan>) : MarkdownBlock
}

/** A run of text with the emphasis that applies to it. */
data class InlineSpan(val text: String, val bold: Boolean = false, val italic: Boolean = false)

private val BULLET = Regex("""^\s*[-*+]\s+(.*)$""")
private val HEADING = Regex("""^\s*(#{1,6})\s+(.*)$""")

/**
 * Splits `**bold**`, `__bold__`, `*italic*` and `_italic_` into flat spans.
 *
 * Two-character markers are matched before one-character ones, so `**x**` is one
 * bold span rather than an italic wrapping a stray asterisk. Nesting is not
 * supported and does not need to be — the model does not emit it, and treating
 * an unmatched marker as literal text is safer than guessing at intent.
 */
fun parseInlineSpans(text: String): List<InlineSpan> {
    val spans = mutableListOf<InlineSpan>()
    val literal = StringBuilder()

    fun flush() {
        if (literal.isNotEmpty()) {
            spans.add(InlineSpan(literal.toString()))
            literal.clear()
        }
    }

    var i = 0
    while (i < text.length) {
        val rest = text.substring(i)
        val marker = when {
            rest.startsWith("**") -> "**"
            rest.startsWith("__") -> "__"
            rest.startsWith("*") -> "*"
            rest.startsWith("_") -> "_"
            else -> null
        }
        if (marker == null) {
            literal.append(text[i])
            i++
            continue
        }
        val closeAt = text.indexOf(marker, startIndex = i + marker.length)
        // An unmatched marker is just a character the author typed.
        if (closeAt < 0) {
            literal.append(text[i])
            i++
            continue
        }
        val inner = text.substring(i + marker.length, closeAt)
        // `** **` with nothing inside is not emphasis; keep it literal.
        if (inner.isEmpty()) {
            literal.append(text[i])
            i++
            continue
        }
        flush()
        val bold = marker.length == 2
        spans.add(InlineSpan(inner, bold = bold, italic = !bold))
        i = closeAt + marker.length
    }
    flush()
    return spans
}

/** Blocks in source order. Blank lines separate paragraphs; a hard newline
 *  inside a paragraph is preserved, since the model uses single newlines to
 *  break lines of evidence that belong together. */
fun parseMarkdownBlocks(markdown: String): List<MarkdownBlock> {
    val blocks = mutableListOf<MarkdownBlock>()
    val paragraph = mutableListOf<String>()

    fun flushParagraph() {
        if (paragraph.isNotEmpty()) {
            blocks.add(MarkdownBlock.Paragraph(parseInlineSpans(paragraph.joinToString("\n"))))
            paragraph.clear()
        }
    }

    for (line in markdown.lines()) {
        val heading = HEADING.matchEntire(line)
        val bullet = BULLET.matchEntire(line)
        when {
            line.isBlank() -> flushParagraph()
            heading != null -> {
                flushParagraph()
                blocks.add(
                    MarkdownBlock.Heading(
                        level = heading.groupValues[1].length,
                        spans = parseInlineSpans(heading.groupValues[2]),
                    ),
                )
            }
            bullet != null -> {
                flushParagraph()
                blocks.add(MarkdownBlock.Bullet(parseInlineSpans(bullet.groupValues[1])))
            }
            else -> paragraph.add(line)
        }
    }
    flushParagraph()
    return blocks
}
