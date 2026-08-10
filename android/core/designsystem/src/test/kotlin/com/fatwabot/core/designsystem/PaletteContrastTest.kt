package com.fatwabot.core.designsystem

import androidx.compose.ui.graphics.Color
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Legibility guards on the bundled palettes — mirror of the iOS
 * `PaletteContrastTests`. Both platforms must enforce the same contract, or a
 * palette change lands on one and quietly degrades the other.
 *
 * See DesignTokens.kt for why `primary` is held to the 3:1 large-text bar rather
 * than 4.5:1: on a near-black ground no single token can clear 4.5 both as text
 * on the surface and under near-white as a fill.
 */
class PaletteContrastTest {

    /** WCAG 2.1 relative luminance. */
    private fun luminance(color: Color): Double =
        listOf(color.red, color.green, color.blue)
            .map { it.toDouble() }
            .map { if (it <= 0.04045) it / 12.92 else ((it + 0.055) / 1.055).pow(2.4) }
            .let { (r, g, b) -> 0.2126 * r + 0.7152 * g + 0.0722 * b }

    /** WCAG contrast ratio, 1.0 through 21.0. */
    private fun contrast(foreground: Color, background: Color): Double {
        val a = luminance(foreground)
        val b = luminance(background)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    private fun assertContrast(
        foreground: Color,
        background: Color,
        bar: Double,
        label: String,
    ) {
        val ratio = contrast(foreground, background)
        assertTrue(
            "$label measures %.2f:1, below the %.1f:1 bar".format(ratio, bar),
            ratio >= bar,
        )
    }

    private val schemes = listOf("light" to LightTokens, "dark" to DarkTokens)

    @Test
    fun `body text clears AA in both schemes`() {
        for ((name, t) in schemes) {
            assertContrast(t.onSurface, t.surface, BODY_BAR, "$name onSurface/surface")
            assertContrast(t.onSurface, t.surfaceElevated, BODY_BAR, "$name onSurface/elevated")
            // Secondary text is smaller, not larger — same bar.
            assertContrast(t.onSurfaceSecondary, t.surface, BODY_BAR, "$name secondary/surface")
            assertContrast(
                t.onSurfaceSecondary, t.surfaceElevated, BODY_BAR, "$name secondary/elevated",
            )
        }
    }

    /**
     * `primary` is a heading/icon foreground as well as a fill.
     *
     * As on iOS, this is a floor against gross failures rather than a tight
     * guard: the previous #B8514A measured 3.48:1 on a card and would have
     * passed. What surfaces a marginal palette is
     * [documented dark measurements are accurate], which forces the real numbers
     * into the source where a reviewer sees them.
     */
    @Test
    fun `primary as text clears the large-text bar`() {
        for ((name, t) in schemes) {
            assertContrast(t.primary, t.surface, LARGE_TEXT_BAR, "$name primary-as-text/surface")
            assertContrast(
                t.primary, t.surfaceElevated, LARGE_TEXT_BAR, "$name primary-as-text/elevated",
            )
        }
    }

    /** Near-white on the `primary` fill — nav band and search cap, large bold. */
    @Test
    fun `onPrimary clears the large-text bar`() {
        for ((name, t) in schemes) {
            assertContrast(t.onPrimary, t.primary, LARGE_TEXT_BAR, "$name onPrimary/primary")
        }
    }

    /**
     * Cards are separated from the page by fill, border, or both. On a true-black
     * surface the fill step is small by design, so the outline carries it.
     */
    @Test
    fun `card boundary is perceptible`() {
        for ((name, t) in schemes) {
            val fillStep = contrast(t.surfaceElevated, t.surface)
            val border = contrast(t.outline, t.surfaceElevated)
            assertTrue(
                "$name card has no visible boundary: fill %.2f, border %.2f"
                    .format(fillStep, border),
                max(fillStep, border) > 1.15,
            )
        }
    }

    /**
     * The reference values documented in DesignTokens.kt. Fails loudly if the
     * palette is edited without updating the recorded measurements — which is how
     * the comment drifted from reality last time.
     *
     * The light-mode `accent` gap (#B8860B at 2.96:1 on the cream surface, under
     * even the large-text floor) is deliberately *not* asserted as passing here;
     * it is tracked on iOS as an expected failure pending an owner decision.
     */
    @Test
    fun `documented dark measurements are accurate`() {
        val d = DarkTokens
        val cases = listOf(
            Triple("onSurface/surface", contrast(d.onSurface, d.surface), 21.00),
            Triple("primary/surface", contrast(d.primary, d.surface), 4.78),
            Triple("primary/elevated", contrast(d.primary, d.surfaceElevated), 4.26),
            Triple("onPrimary/primary", contrast(d.onPrimary, d.primary), 4.16),
            Triple("accent/surface", contrast(d.accent, d.surface), 12.78),
        )
        for ((label, measured, documented) in cases) {
            assertEquals(
                "$label is %.2f, but DesignTokens.kt documents %.2f".format(measured, documented),
                documented, measured, 0.01,
            )
        }
    }

    private companion object {
        /** Normal-size body text. */
        const val BODY_BAR = 4.5
        /** 18pt+, or 14pt+ bold. */
        const val LARGE_TEXT_BAR = 3.0
    }
}
