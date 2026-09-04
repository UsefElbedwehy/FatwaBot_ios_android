package com.fatwabot.feature.prayer

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Explore
import androidx.compose.material.icons.filled.WarningAmber
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.fatwabot.core.designsystem.BrandCard
import com.fatwabot.core.designsystem.BrandMark
import com.fatwabot.core.designsystem.ColorTokens
import com.fatwabot.core.designsystem.DarkTokens
import com.fatwabot.core.designsystem.LightTokens
import com.fatwabot.core.designsystem.LocalReduceMotion
import com.fatwabot.core.designsystem.MihrabArchComposeShape
import com.fatwabot.core.designsystem.MotionTokens
import com.fatwabot.core.designsystem.brandScreenBackground
import com.fatwabot.core.designsystem.motionAnimationSpec
import com.fatwabot.core.prayer.PrayerCalculator
import kotlinx.coroutines.flow.collect

/** Compass (docs/features/prayer.md §Qibla) — mirror of iOS QiblaScreen.
 * Falls back to a static bearing display when the device has no rotation
 * sensor (matches iOS's staticFallback for sensor-less devices). */
@Composable
fun QiblaScreen(location: UserLocation, provider: HeadingProviding? = null) {
    val context = LocalContext.current
    // `remember`ed, and NOT a default parameter value: a default argument is
    // re-evaluated on every recomposition, so each sensor sample built a new
    // provider, changed the LaunchedEffect key, and tore down + re-registered
    // the sensor listener — every frame. That churn is why the compass read as
    // frozen or wildly jumpy. The location is part of the key because the
    // provider needs it for the magnetic-declination correction.
    val headingProvider = remember(provider, context, location.latitude, location.longitude) {
        provider ?: SystemHeadingProvider(context, location.latitude, location.longitude)
    }
    val bearing = remember(location) { PrayerCalculator().qiblaBearing(location.latitude, location.longitude) }
    var heading by remember { mutableDoubleStateOf(0.0) }
    var accuracy by remember { mutableStateOf(-1.0) }
    val tokens = if (isSystemInDarkTheme()) DarkTokens else LightTokens

    LaunchedEffect(headingProvider) {
        if (headingProvider.supportsHeading) {
            headingProvider.headings().collect {
                // Unwrapped HERE, at the source, into a continuously-increasing
                // value — not in composition. `heading` therefore never jumps
                // 359° → 1°, so the animation downstream is a plain tween with
                // no seam to special-case and nothing restarting it per sample.
                val delta = ((it.heading - heading + 540) % 360) - 180
                heading += delta
                accuracy = it.accuracy
            }
        }
    }

    Box(modifier = Modifier.fillMaxSize().brandScreenBackground(tokens)) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(20.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(24.dp),
        ) {
            if (!headingProvider.supportsHeading) {
                StaticFallback(bearing, tokens)
            } else {
                CompassCard(bearing = bearing, heading = heading, tokens = tokens)
                AccuracyNotice(accuracy = accuracy, tokens = tokens)
            }
        }
    }
}

/** The compass housed in an elevated circular card carrying the mihrab gradient. */
@Composable
private fun CompassCard(bearing: Double, heading: Double, tokens: ColorTokens) {
    val needleAngle = bearing - heading
    val isAligned = isAlignedTo(needleAngle)
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(18.dp),
    ) {
        Box(
            modifier = Modifier
                .size(300.dp)
                .background(
                    Brush.linearGradient(
                        listOf(tokens.surfaceElevated, tokens.primaryContainer.copy(alpha = 0.5f)),
                    ),
                    CircleShape,
                )
                .border(1.dp, tokens.primary.copy(alpha = 0.15f), CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            Compass(bearing = bearing, heading = heading, isAligned = isAligned, tokens = tokens)
        }
        BearingReadout(bearing = bearing, isAligned = isAligned, tokens = tokens)
    }
}

@Composable
private fun Compass(bearing: Double, heading: Double, isAligned: Boolean, tokens: ColorTokens) {
    val reduceMotion = LocalReduceMotion.current
    // Resolved here: stringResource is a @Composable and can't be called from
    // inside the semantics lambda.
    val compassDesc = stringResource(R.string.qibla_compass_desc)
    // ONE animated value drives both the needle and the cardinal ring. They
    // used to animate off different sources — the needle tweened while the
    // N/E/S/W letters snapped to the raw heading — so the two visibly lagged
    // each other while turning.
    // `heading` arrives already unwrapped (see QiblaScreen), so this is a plain
    // tween that always takes the short way round.
    val animatedHeading by animateFloatAsState(
        targetValue = heading.toFloat(),
        animationSpec = motionAnimationSpec(reduceMotion, MotionTokens.QUICK_MS),
        label = "qibla-heading",
    )
    val needleAngle = bearing.toFloat() - animatedHeading

    Box(
        modifier = Modifier
            .size(260.dp)
            .border(2.dp, tokens.outline, CircleShape)
            .semantics(mergeDescendants = true) {},
        contentAlignment = Alignment.Center,
    ) {
        listOf("N", "E", "S", "W").forEachIndexed { index, point ->
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .rotate((index * 90).toFloat() - animatedHeading),
                contentAlignment = Alignment.TopCenter,
            ) {
                Text(
                    point,
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = tokens.onSurfaceSecondary,
                    modifier = Modifier.padding(top = 8.dp),
                )
            }
        }
        // A faint mihrab arch turning with the needle, as on iOS — it gives the
        // rotation something to read against besides the mark itself.
        Box(
            modifier = Modifier
                .size(150.dp)
                .rotate(needleAngle)
                .background(tokens.primary.copy(alpha = 0.06f), MihrabArchComposeShape),
        )
        // The app's own mark is the pointer (owner request, matching iOS).
        // This also fixes a real bug: the previous Icons.Filled.NearMe glyph
        // points to its top-RIGHT corner, i.e. 45° clockwise of vertical, so
        // every reading was silently rotated 45° off.
        BrandMark(
            color = if (isAligned) tokens.accent else tokens.primary,
            modifier = Modifier
                .height(76.dp)
                .rotate(needleAngle)
                .semantics { contentDescription = compassDesc },
        )
    }
}

/** Prominent qibla bearing readout below the compass. */
@Composable
private fun BearingReadout(bearing: Double, isAligned: Boolean, tokens: ColorTokens) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(
            "${bearing.toInt()}°",
            style = MaterialTheme.typography.displaySmall,
            fontWeight = FontWeight.ExtraBold,
            color = if (isAligned) tokens.accent else tokens.primary,
        )
        // The number alone doesn't say what it is or how to use it; iOS carries
        // the same caption under its readout.
        Text(
            stringResource(R.string.qibla_compass_desc),
            style = MaterialTheme.typography.bodySmall,
            color = tokens.onSurfaceSecondary,
            textAlign = TextAlign.Center,
        )
    }
}

/** True near 0° or 180° apart (needle pointing at the target within ±5°). */
private fun isAlignedTo(needleAngle: Double): Boolean {
    val normalized = ((needleAngle % 360) + 360) % 360
    val delta = kotlin.math.min(normalized, 360 - normalized)
    return delta < 5
}

@Composable
private fun AccuracyNotice(accuracy: Double, tokens: ColorTokens) {
    val notice: Pair<ImageVector, String>? = when {
        accuracy < 0 -> Icons.Filled.Explore to stringResource(R.string.qibla_calibrating)
        accuracy > 25 -> Icons.Filled.WarningAmber to stringResource(R.string.qibla_magnetic_interference)
        else -> null
    }
    notice?.let { (icon, text) ->
        BrandCard(tokens = tokens) {
            Row(
                modifier = Modifier.fillMaxWidth().semantics(mergeDescendants = true) {},
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Icon(icon, contentDescription = null, tint = tokens.accent)
                Text(text, color = tokens.onSurfaceSecondary, style = MaterialTheme.typography.bodyMedium)
            }
        }
    }
}

@Composable
private fun StaticFallback(bearing: Double, tokens: ColorTokens) {
    BrandCard(tokens = tokens, contentPadding = 24.dp) {
        Column(
            modifier = Modifier.fillMaxWidth().semantics(mergeDescendants = true) {},
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            // The app's mark in the arch, not a generic compass glyph — same
            // BrandLogoBadge treatment iOS uses on this fallback.
            Box(
                modifier = Modifier
                    .size(72.dp)
                    .background(tokens.primaryContainer, MihrabArchComposeShape),
                contentAlignment = Alignment.Center,
            ) {
                BrandMark(color = tokens.primary, modifier = Modifier.height(38.dp))
            }
            Text(
                stringResource(R.string.qibla_direction, bearing.toInt()),
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                color = tokens.onSurface,
                textAlign = TextAlign.Center,
            )
        }
    }
}
