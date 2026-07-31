package com.fatwabot.core.designsystem

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathFillType
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.material3.Text

/**
 * The streak flame — mirror of iOS `StreakFlameShape`.
 *
 * Asymmetric on purpose: a symmetric teardrop reads as a balloon. The lean and
 * the notched left shoulder are what make it read as fire at small sizes.
 */
fun streakFlamePath(size: Size): Path {
    val w = size.width
    val h = size.height
    val tipX = w * 0.52f
    return Path().apply {
        fillType = PathFillType.NonZero
        moveTo(tipX, 0f)
        // Right flank: swings wide, then tucks under the base.
        cubicTo(w * 0.70f, h * 0.20f, w * 0.98f, h * 0.34f, w * 0.98f, h * 0.62f)
        cubicTo(w * 0.98f, h * 0.86f, w * 0.79f, h, w * 0.50f, h)
        // Left flank back up.
        cubicTo(w * 0.21f, h, w * 0.02f, h * 0.85f, w * 0.03f, h * 0.60f)
        // The notch — the kink that separates fire from teardrop.
        cubicTo(w * 0.04f, h * 0.42f, w * 0.30f, h * 0.46f, w * 0.34f, h * 0.30f)
        cubicTo(w * 0.38f, h * 0.16f, w * 0.44f, h * 0.10f, tipX, 0f)
        close()
    }
}

/** Size presets, matching the iOS `StreakBadge.Size` cases 1:1. */
enum class StreakBadgeSize(val flameHeight: Dp, val countSize: TextUnit) {
    SMALL(34.dp, 15.sp),
    MEDIUM(56.dp, 24.sp),
    LARGE(88.dp, 40.sp),
}

/**
 * Flame + brand mark + count — mirror of the iOS `StreakBadge`
 * (owner decision, 2026-07: the streak reads as fire, the app mark, and a
 * number).
 *
 * The count sits *below* the flame rather than inside it. Inside looks tighter
 * in a mockup, but the mark already occupies the flame's optical centre, and a
 * three-digit streak — the one worth being proud of — has nowhere to go: it
 * either shrinks to unreadable or collides with the mark.
 *
 * @param isActive whether the streak is still alive today. A cold flame is how
 *   a lapsed streak should look; greying only the number reads as "loading".
 */
@Composable
fun StreakBadge(
    count: Int,
    tokens: ColorTokens,
    modifier: Modifier = Modifier,
    size: StreakBadgeSize = StreakBadgeSize.MEDIUM,
    isActive: Boolean = true,
    contentDescription: String? = null,
) {
    val flameColors = if (isActive) {
        listOf(tokens.accent, tokens.primary)
    } else {
        listOf(tokens.onSurfaceSecondary.copy(alpha = 0.45f), tokens.onSurfaceSecondary.copy(alpha = 0.28f))
    }
    Column(
        modifier = modifier.then(
            if (contentDescription != null) {
                Modifier.semantics { this.contentDescription = contentDescription }
            } else {
                Modifier
            },
        ),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(if (size == StreakBadgeSize.LARGE) 6.dp else 3.dp),
    ) {
        Box(contentAlignment = Alignment.Center) {
            Canvas(modifier = Modifier.size(size.flameHeight * 0.82f, size.flameHeight)) {
                drawPath(
                    path = streakFlamePath(this.size),
                    brush = Brush.verticalGradient(flameColors),
                )
            }
            // The mark sits low in the flame, where the body is widest —
            // centring it in the bounding box would push it into the taper.
            Canvas(
                modifier = Modifier
                    .size(size.flameHeight * 0.40f)
                    .offset(y = size.flameHeight * 0.12f),
            ) {
                drawPath(path = mihrabArchPath(this.size), color = tokens.onPrimary)
            }
        }
        Text(
            text = "$count",
            color = if (isActive) tokens.primary else tokens.onSurfaceSecondary,
            fontSize = size.countSize,
            fontWeight = if (size == StreakBadgeSize.LARGE) FontWeight.ExtraBold else FontWeight.Bold,
            fontFamily = FontFamily.SansSerif,
            textAlign = TextAlign.Center,
        )
    }
}
