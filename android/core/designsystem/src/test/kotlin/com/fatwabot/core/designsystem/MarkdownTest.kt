package com.fatwabot.core.designsystem

import org.junit.Assert.assertEquals
import org.junit.Test

class MarkdownTest {

    @Test
    fun `bold marker becomes a bold span, not literal asterisks`() {
        assertEquals(
            listOf(InlineSpan("الحكم الراجح", bold = true)),
            parseInlineSpans("**الحكم الراجح**"),
        )
    }

    @Test
    fun `bold in the middle keeps the surrounding text`() {
        assertEquals(
            listOf(
                InlineSpan("قال "),
                InlineSpan("النبي", bold = true),
                InlineSpan(" صلى الله عليه وسلم"),
            ),
            parseInlineSpans("قال **النبي** صلى الله عليه وسلم"),
        )
    }

    @Test
    fun `single asterisk is italic, double is bold`() {
        assertEquals(listOf(InlineSpan("x", italic = true)), parseInlineSpans("*x*"))
        assertEquals(listOf(InlineSpan("x", bold = true)), parseInlineSpans("**x**"))
    }

    @Test
    fun `an unmatched marker stays literal rather than eating the rest`() {
        // Scripture must never lose a character to a parser guessing at intent.
        assertEquals(listOf(InlineSpan("2 * 3 = 6")), parseInlineSpans("2 * 3 = 6"))
        assertEquals(listOf(InlineSpan("قال **")), parseInlineSpans("قال **"))
    }

    @Test
    fun `an empty marker pair is literal`() {
        assertEquals(listOf(InlineSpan("****")), parseInlineSpans("****"))
    }

    @Test
    fun `dash and asterisk both start a bullet`() {
        val blocks = parseMarkdownBlocks("- من الكتاب\n* من السنة")
        assertEquals(
            listOf(
                MarkdownBlock.Bullet(listOf(InlineSpan("من الكتاب"))),
                MarkdownBlock.Bullet(listOf(InlineSpan("من السنة"))),
            ),
            blocks,
        )
    }

    @Test
    fun `hash prefix becomes a heading carrying its level`() {
        assertEquals(
            listOf(MarkdownBlock.Heading(2, listOf(InlineSpan("الأدلة")))),
            parseMarkdownBlocks("## الأدلة"),
        )
    }

    @Test
    fun `a blank line splits paragraphs and a single newline does not`() {
        val blocks = parseMarkdownBlocks("سطر أول\nسطر ثانٍ\n\nفقرة أخرى")
        assertEquals(
            listOf(
                MarkdownBlock.Paragraph(listOf(InlineSpan("سطر أول\nسطر ثانٍ"))),
                MarkdownBlock.Paragraph(listOf(InlineSpan("فقرة أخرى"))),
            ),
            blocks,
        )
    }

    @Test
    fun `a real answer parses into the blocks it looks like`() {
        // Shape taken from an actual production answer to "صلاة الجماعة".
        val answer = """
            صلاة الجماعة من أوكد العبادات.

            **الحكم الراجح عند ابن عثيمين:**
            واجبة على كل مسلم بالغ.

            **الأدلة على الوجوب:**
            - من الكتاب: آية صلاة الخوف.
            - من السنة: أحاديث كثيرة.
        """.trimIndent()

        val blocks = parseMarkdownBlocks(answer)

        // Five, not six: the bold "heading" line and the sentence under it are
        // consecutive non-blank lines, so they are one paragraph with a soft
        // break — which is what the model means by them.
        assertEquals(5, blocks.size)
        // Bold-only lines are paragraphs whose single span is bold — the model
        // writes headings that way rather than with `#`, and they must not come
        // out as literal asterisks.
        val second = blocks[1] as MarkdownBlock.Paragraph
        assertEquals(true, second.spans.first().bold)
        assertEquals("الحكم الراجح عند ابن عثيمين:", second.spans.first().text)
        assertEquals(2, blocks.count { it is MarkdownBlock.Bullet })
        // Nothing anywhere still carries a raw marker.
        val allText = blocks.joinToString("") { block ->
            when (block) {
                is MarkdownBlock.Paragraph -> block.spans.joinToString("") { it.text }
                is MarkdownBlock.Bullet -> block.spans.joinToString("") { it.text }
                is MarkdownBlock.Heading -> block.spans.joinToString("") { it.text }
            }
        }
        assertEquals(false, allText.contains("**"))
    }
}
