package com.fatwabot.core.designsystem

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.Outline
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathFillType
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp

/**
 * Pointed-arch ("mihrab") silhouette — the same Islamic-architecture motif
 * used by the iOS `MihrabArchShape`, ported to a Compose `Path` so onboarding
 * icons read as more than generic Material glyphs (stakeholder direction,
 * 2026-07-11: "can we make better islamic shapes in the onboarding?").
 */
/**
 * @param archRatio how much of the height the curve occupies. Mirrors iOS
 *   `MihrabArchShape.archRatio` — the Qibla motif passes 0.6 for a taller arch.
 */
fun mihrabArchPath(size: Size, archRatio: Float = 0.55f): Path {
    val w = size.width
    val h = size.height
    // Springline at h - curve (0.45h at the default ratio), and the control
    // point ABOVE the top edge at -0.0175h. Both matter: the raised control is
    // what gives the apex its lancet point. This used to spring at 0.42h with
    // the control exactly on y=0, whose horizontal tangents produced a *round
    // dome* — the wrong silhouette for a mihrab, and the whole reason the
    // shape exists.
    val curve = h * archRatio
    val shoulderY = h - curve
    val controlY = shoulderY - curve * 0.85f
    return Path().apply {
        fillType = PathFillType.NonZero
        moveTo(0f, h)
        lineTo(0f, shoulderY)
        quadraticTo(0f, controlY, w / 2f, 0f)
        quadraticTo(w, controlY, w, shoulderY)
        lineTo(w, h)
        close()
    }
}

/**
 * A Material icon inside a filled + stroked mihrab arch.
 *
 * Sized 92×104 by default, not square: the arch has an aspect ratio (iOS uses
 * the same pair), and forcing a square made it ~13% squatter everywhere. The
 * glyph is nudged down by 12% of the height so it sits in the arch's body
 * rather than up inside the taper.
 */
@Composable
fun ArchIconBadge(
    icon: ImageVector,
    modifier: Modifier = Modifier,
    width: Dp = 92.dp,
    height: Dp = 104.dp,
    tokens: ColorTokens = if (androidx.compose.foundation.isSystemInDarkTheme()) DarkTokens else LightTokens,
) {
    Box(
        modifier = modifier
            .size(width, height)
            .background(tokens.primaryContainer, MihrabArchComposeShape)
            // 2dp primary outline, as on iOS — the KDoc claimed "filled+stroked"
            // but no stroke was ever drawn.
            .drawBehind {
                drawPath(
                    path = mihrabArchPath(this.size),
                    color = tokens.primary,
                    style = Stroke(width = 2.dp.toPx()),
                )
            },
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            icon,
            contentDescription = null,
            tint = tokens.primary,
            modifier = Modifier
                .padding(top = height * 0.12f)
                .size(width * 0.32f),
        )
    }
}

/** The arch as a clip/background [Shape]. Public because the Qibla compass
 *  builds its own arch-framed badge and its rotating motif from it, rather
 *  than going through [ArchIconBadge] (which only ever hosts an icon). */
val MihrabArchComposeShape = object : Shape {
    override fun createOutline(size: Size, layoutDirection: LayoutDirection, density: Density): Outline =
        Outline.Generic(mihrabArchPath(size))
}
