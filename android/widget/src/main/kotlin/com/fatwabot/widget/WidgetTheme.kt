package com.fatwabot.widget

import android.content.Context
import android.content.Intent
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.glance.GlanceModifier
import androidx.glance.action.clickable
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.cornerRadius
import androidx.glance.background
import androidx.glance.unit.ColorProvider
import com.fatwabot.core.common.DeepLink

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

// Tile fills for the worship tracker. Tinted maroon rather than a grey/green
// pair so a done tile reads as "brand accent, filled in" at a glance without
// introducing a colour the design system does not already use.
internal val DoneTileProvider = ColorProvider(BrandMaroon.copy(alpha = 0.16f))
internal val IdleTileProvider = ColorProvider(BrandMaroon.copy(alpha = 0.06f))

/** Cream card that fills the widget cell, with the platform-typical rounding. */
internal fun GlanceModifier.brandSurface(): GlanceModifier =
    this.background(ColorProvider(BrandCream)).cornerRadius(20.dp)

/**
 * Makes the whole widget open [link] in the app.
 *
 * `:widget` can't reference `MainActivity` (`:app` depends on `:widget`, not the
 * other way round), so this goes out as an ACTION_VIEW intent carrying the deep
 * link URI. `setPackage` keeps it explicit — without it Android would offer a
 * chooser, or another app claiming `fatwabot://` could intercept the tap.
 */
internal fun GlanceModifier.opensApp(context: Context, link: DeepLink): GlanceModifier =
    this.clickable(
        actionStartActivity(
            Intent(Intent.ACTION_VIEW, link.uri)
                .setPackage(context.packageName)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        ),
    )
