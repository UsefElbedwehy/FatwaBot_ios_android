package com.fatwabot.core.designsystem

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Info
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/**
 * Premium, token-driven Compose building blocks — the Android mirror of iOS
 * `DesignSystemKit/BrandKit.swift`. Give every screen the warm cream + elevated
 * maroon-accented card language from docs/05_DESIGN_DIRECTION.md instead of flat
 * Material defaults (stakeholder direction, 2026-07-11: parity with iOS premium
 * redesign; screens must not look like stock components).
 */

@Composable
private fun brandTokens(): ColorTokens = if (isSystemInDarkTheme()) DarkTokens else LightTokens

// MARK: Screen background

/**
 * Warm cream wash + a soft brand glow in the top-end corner.
 * Apply to the root container of a scrollable screen.
 */
fun Modifier.brandScreenBackground(tokens: ColorTokens): Modifier =
    this
        .background(
            Brush.verticalGradient(
                colors = listOf(tokens.surface, tokens.primaryContainer.copy(alpha = 0.35f)),
            ),
        )
        .drawBehind {
            // Soft corner glow instead of a clipped arch silhouette. Any
            // hard-edged shape bled into the corner reads as a stray
            // square/rectangle (its straight jambs and flat base stay on-screen
            // while the curve goes off it) — rotating it wasn't enough. A radial
            // gradient has no edges at all, so it can only read as brand warmth.
            drawRect(
                brush = Brush.radialGradient(
                    colors = listOf(
                        tokens.primary.copy(alpha = 0.07f),
                        tokens.primary.copy(alpha = 0f),
                    ),
                    center = Offset(size.width, 0f),
                    radius = size.minDimension * 1.1f,
                ),
            )
        }

// MARK: Card

/**
 * Elevated rounded card — the primary content container. Soft shadow + hairline
 * outline for real depth instead of flat surfaces.
 */
@Composable
fun BrandCard(
    modifier: Modifier = Modifier,
    tokens: ColorTokens = brandTokens(),
    cornerRadius: Int = 20,
    contentPadding: Dp = 16.dp,
    content: @Composable () -> Unit,
) {
    Surface(
        shape = RoundedCornerShape(cornerRadius.dp),
        color = tokens.surfaceElevated,
        modifier = modifier
            .fillMaxWidth()
            .shadow(elevation = 6.dp, shape = RoundedCornerShape(cornerRadius.dp), clip = false)
            .border(1.dp, tokens.outline.copy(alpha = 0.6f), RoundedCornerShape(cornerRadius.dp)),
    ) {
        Box(modifier = Modifier.padding(contentPadding)) { content() }
    }
}

// MARK: Section header

/** Premium section header: a maroon→gold accent bar + optional icon + title. */
@Composable
fun BrandSectionHeader(
    title: String,
    modifier: Modifier = Modifier,
    icon: ImageVector? = null,
    tokens: ColorTokens = brandTokens(),
    trailing: (@Composable () -> Unit)? = null,
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier = Modifier
                .width(4.dp)
                .height(18.dp)
                .background(
                    Brush.verticalGradient(listOf(tokens.primary, tokens.accent)),
                    RoundedCornerShape(2.dp),
                ),
        )
        Spacer(Modifier.width(10.dp))
        if (icon != null) {
            Icon(icon, contentDescription = null, tint = tokens.primary, modifier = Modifier.size(18.dp))
            Spacer(Modifier.width(8.dp))
        }
        Text(
            title,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
            color = tokens.onSurface,
        )
        if (trailing != null) {
            Spacer(Modifier.weight(1f))
            trailing()
        }
    }
}

// MARK: Brand mark (mihrab arch glyph)

/**
 * The app's brand mark.
 *
 * Draws the real logo asset rather than the hand-traced mihrab arch. The arch
 * was a stand-in from before the logo existed, and it kept surfacing in places
 * a user reads as "the app's icon" — the streaks list among them — where a
 * near-miss of the brand is worse than either the mark or nothing.
 *
 * Tinted with [color] so it still reads correctly on a coloured container, the
 * same way the iOS `FatwaMark` renders its asset as a template.
 */
@Composable
fun BrandMark(
    modifier: Modifier = Modifier,
    color: Color = brandTokens().primary,
) {
    androidx.compose.foundation.Image(
        painter = androidx.compose.ui.res.painterResource(R.drawable.fatwabot_logo),
        contentDescription = null,
        modifier = modifier,
        colorFilter = androidx.compose.ui.graphics.ColorFilter.tint(color),
    )
}

// MARK: Ring progress

/** Circular progress ring with a maroon→gold sweep and a faint track. */
@Composable
fun RingProgress(
    value: Float,
    modifier: Modifier = Modifier,
    strokeWidth: Dp = 8.dp,
    tokens: ColorTokens = brandTokens(),
) {
    val clamped = value.coerceIn(0f, 1f)
    androidx.compose.foundation.Canvas(modifier = modifier) {
        val stroke = strokeWidth.toPx()
        val inset = stroke / 2f
        val arcSize = Size(size.width - stroke, size.height - stroke)
        drawArc(
            color = tokens.primary.copy(alpha = 0.14f),
            startAngle = 0f,
            sweepAngle = 360f,
            useCenter = false,
            topLeft = Offset(inset, inset),
            size = arcSize,
            style = Stroke(width = stroke, cap = StrokeCap.Round),
        )
        drawArc(
            brush = Brush.sweepGradient(listOf(tokens.primary, tokens.accent, tokens.primary)),
            startAngle = -90f,
            sweepAngle = 360f * clamped,
            useCenter = false,
            topLeft = Offset(inset, inset),
            size = arcSize,
            style = Stroke(width = stroke, cap = StrokeCap.Round),
        )
    }
}

// MARK: Rank medal

/** Leaderboard rank badge — gold/silver/bronze disc for the top three. */
@Composable
fun RankMedal(rank: Int, modifier: Modifier = Modifier, tokens: ColorTokens = brandTokens()) {
    val medal: List<Color>? = when (rank) {
        1 -> listOf(Color(0xFFD9AE4D), Color(0xFFB88829))
        2 -> listOf(Color(0xFFC7C7CC), Color(0xFF9A9AA0))
        3 -> listOf(Color(0xFFCC8C59), Color(0xFF9E663D))
        else -> null
    }
    Box(
        modifier = modifier
            .size(34.dp)
            .background(
                if (medal != null) Brush.verticalGradient(medal)
                else Brush.verticalGradient(listOf(tokens.primaryContainer, tokens.primaryContainer)),
                RoundedCornerShape(50),
            ),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            "$rank",
            style = MaterialTheme.typography.labelLarge,
            fontWeight = FontWeight.Bold,
            color = if (medal != null) Color.White else tokens.primary,
        )
    }
}

// MARK: Empty state

/** Consistent branded empty state: arch-badged icon + message. */
@Composable
fun BrandEmptyState(
    icon: ImageVector,
    message: String,
    modifier: Modifier = Modifier,
    tokens: ColorTokens = brandTokens(),
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 24.dp, vertical = 44.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        ArchIconBadge(icon = icon, size = 74.dp, tokens = tokens)
        Text(
            message,
            style = MaterialTheme.typography.bodyMedium,
            color = tokens.onSurfaceSecondary,
            textAlign = TextAlign.Center,
        )
    }
}

// MARK: Info notice

/**
 * Soft informational banner — an ⓘ glyph beside a short passage, used to carry
 * a study/advisory note above a screen's content.
 *
 * The copy is deliberately NOT baked in: callers pass a resolved string so it can
 * come from the server string pack (ADR-0011) and be changed without a release.
 * Rendered in brand tones rather than the system blue so it reads as part of the
 * app instead of an OS alert.
 */
@Composable
fun InfoNotice(
    text: String,
    modifier: Modifier = Modifier,
    tokens: ColorTokens = brandTokens(),
) {
    val shape = RoundedCornerShape(14.dp)
    Row(
        modifier = modifier
            .fillMaxWidth()
            .background(tokens.primaryContainer.copy(alpha = 0.55f), shape)
            .border(1.dp, tokens.primary.copy(alpha = 0.14f), shape)
            .padding(14.dp),
        verticalAlignment = Alignment.Top,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Icon(
            Icons.Filled.Info,
            contentDescription = null,
            tint = tokens.primary,
            modifier = Modifier.size(17.dp),
        )
        Text(
            text,
            style = MaterialTheme.typography.bodySmall,
            color = tokens.onSurface,
            textAlign = TextAlign.Start,
            modifier = Modifier.weight(1f),
        )
    }
}
