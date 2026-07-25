package com.fatwabot.widget

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.glance.GlanceModifier
import androidx.glance.appwidget.cornerRadius
import androidx.glance.background
import androidx.glance.unit.ColorProvider

/**
 * Shared brand palette for the home-screen widgets: maroon on cream, matching the
 * app's design tokens. The widgets paint their own surface rather than inheriting
 * the launcher/system theme, so every text colour must be stated explicitly —
 * otherwise GlanceTheme's dynamic `onSurface` turns light in dark mode and
 * disappears against the cream card.
 */
internal val BrandMaroon = Color(0xFF7A2A2A)
internal val BrandCream = Color(0xFFFAF3EC)
internal val BrandInk = Color(0xFF2A2118)
internal val BrandMuted = Color(0xFF6B5E52)
internal val BrandHighlight = Color(0x1A7A2A2A)

internal val MaroonProvider = ColorProvider(BrandMaroon)
internal val InkProvider = ColorProvider(BrandInk)
internal val MutedProvider = ColorProvider(BrandMuted)

/** Cream card that fills the widget cell, with the platform-typical rounding. */
internal fun GlanceModifier.brandSurface(): GlanceModifier =
    this.background(ColorProvider(BrandCream)).cornerRadius(20.dp)
