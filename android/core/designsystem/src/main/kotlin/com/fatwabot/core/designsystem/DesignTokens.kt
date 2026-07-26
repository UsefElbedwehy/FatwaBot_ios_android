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

// Dark palette notes — `primary` has to do two jobs at once: it fills large
// surfaces (the nav band, the search cap) AND is used as a foreground for
// headings and icons. The old #D08770 was tuned only for the second job: a
// washed-out salmon that read as a different brand once it filled the nav band,
// and it forced `onPrimary` to be *dark*, which is backwards for a fill colour.
//
// #B8514A is a lifted brick that still reads as the maroon family: dark enough
// that near-white sits on it legibly, light enough to carry as a heading against
// the near-black surface. Surfaces gained a clearer elevation delta (a 3-point
// luminance step was invisible), and the gold accent was brightened, since
// #B8860B is nearly black on a dark ground.
val DarkTokens = ColorTokens(
    primary = Color(0xFFB8514A),
    primaryContainer = Color(0xFF3B2320),
    accent = Color(0xFFE0B457),
    surface = Color(0xFF14100F),
    surfaceElevated = Color(0xFF221B19),
    onSurface = Color(0xFFF5EBE4),
    onSurfaceSecondary = Color(0xFFBCA79C),
    onPrimary = Color(0xFFFFF6F1),
    outline = Color(0xFF3E312D),
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
