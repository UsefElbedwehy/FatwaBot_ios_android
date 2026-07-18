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

val DarkTokens = ColorTokens(
    primary = Color(0xFFD08770),
    primaryContainer = Color(0xFF3A2422),
    accent = Color(0xFFD4A73F),
    surface = Color(0xFF171210),
    surfaceElevated = Color(0xFF221A17),
    onSurface = Color(0xFFF1E7E0),
    onSurfaceSecondary = Color(0xFFB5A398),
    onPrimary = Color(0xFF2B1B17),
    outline = Color(0xFF463832),
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
