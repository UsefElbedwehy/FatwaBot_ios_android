package com.fatwabot.core.designsystem

import androidx.compose.ui.graphics.Color

/**
 * Brand token values — bundled defaults mirroring backend/supabase/seed.sql
 * (ADR-0011: fixed schema, server-overridable values; the /v1/config/theme
 * overlay service lands in M1 and must produce identical results to iOS).
 */
data class ColorTokens(
    val primary: Color,
    val primaryContainer: Color,
    val accent: Color,
    val surface: Color,
    val surfaceElevated: Color,
    val onSurface: Color,
    val onSurfaceSecondary: Color,
    val onPrimary: Color,
    val outline: Color,
)

val LightTokens = ColorTokens(
    primary = Color(0xFF7A2A2A),
    primaryContainer = Color(0xFFF3E4E1),
    accent = Color(0xFFB8860B),
    surface = Color(0xFFFAF3EC),
    surfaceElevated = Color(0xFFFFFFFF),
    onSurface = Color(0xFF2B1B17),
    onSurfaceSecondary = Color(0xFF6E5A54),
    onPrimary = Color(0xFFFFFFFF),
    outline = Color(0xFFE3D5CC),
)

// Dark palette — "True Night", chosen by the owner from a rendered comparison
// of five candidates. Mirror of iOS DesignTokens.swift; see the long note there
// for the full reasoning. In short:
//
// `primary` does two jobs — it fills large surfaces (the nav band, the search
// cap) AND is a foreground for headings and icons. On a near-black ground those
// two jobs cannot both clear 4.5:1 with a single token; it is arithmetically
// impossible. So `primary` is tuned for the harder job (body-sized heading
// text) and the fill rides on the 3:1 large-bold-text allowance. The rule that
// falls out: **never put small text on a `primary` fill** — use
// `primaryContainer` for that.
//
// Measured: onSurface/surface 21.00:1 · primary-as-text/surface 4.78:1 (the old
// #B8514A was 3.88 and failed) · primary-as-text/**elevated** 4.26:1 — that last
// one is the number that actually governs, because headings sit on cards rather
// than on the black background. It clears 3:1 but not 4.5, so a `primary`
// heading must stay large and bold · onPrimary/primary 4.16:1 (large bold only)
// · accent/surface 12.78:1.
//
// Trade-off: `surface` is true black for OLED, which leaves one elevation step
// and no third level, so nested rows lean on `outline` rather than their own
// fill. Graded three-level alternatives were built and rejected in favour of
// this one.
val DarkTokens = ColorTokens(
    primary = Color(0xFFC4564B),
    primaryContainer = Color(0xFF351F1C),
    accent = Color(0xFFEFC46B),
    surface = Color(0xFF000000),
    surfaceElevated = Color(0xFF16110F),
    onSurface = Color(0xFFFFFFFF),
    onSurfaceSecondary = Color(0xFFC4B3A9),
    onPrimary = Color(0xFFFFF7F5),
    outline = Color(0xFF2A2320),
)

object ShapeTokens {
    const val CARD_RADIUS_DP = 18
    const val CONTROL_RADIUS_DP = 12
}

/** Shared animation durations (M4 polish pass) — mirror of iOS MotionTokens.
 * QUICK_MS for small value changes (counters, progress bars), STANDARD_MS
 * for screen/section-level transitions. Bundled-only, not server-overridable. */
object MotionTokens {
    const val QUICK_MS = 200
    const val STANDARD_MS = 300
}
