package com.fatwabot.core.designsystem

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Size
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
fun mihrabArchPath(size: Size): Path {
    val w = size.width
    val h = size.height
    val shoulderY = h * 0.42f
    return Path().apply {
        fillType = PathFillType.NonZero
        moveTo(0f, h)
        lineTo(0f, shoulderY)
        quadraticTo(0f, 0f, w / 2f, 0f)
        quadraticTo(w, 0f, w, shoulderY)
        lineTo(w, h)
        close()
    }
}

/** SF Symbol-equivalent: a Material icon centered inside a filled+stroked mihrab arch. */
@Composable
fun ArchIconBadge(
    icon: ImageVector,
    modifier: Modifier = Modifier,
    size: Dp = 72.dp,
    tokens: ColorTokens = if (androidx.compose.foundation.isSystemInDarkTheme()) DarkTokens else LightTokens,
) {
    Box(
        modifier = modifier
            .size(size)
            .background(tokens.primaryContainer, MihrabArchComposeShape),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            icon,
            contentDescription = null,
            tint = tokens.primary,
            modifier = Modifier.size(size * 0.44f),
        )
    }
}

private val MihrabArchComposeShape = object : Shape {
    override fun createOutline(size: Size, layoutDirection: LayoutDirection, density: Density): Outline =
        Outline.Generic(mihrabArchPath(size))
}
