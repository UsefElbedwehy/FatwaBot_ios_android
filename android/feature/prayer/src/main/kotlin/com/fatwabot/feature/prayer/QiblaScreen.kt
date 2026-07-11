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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Explore
import androidx.compose.material.icons.filled.NearMe
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
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.fatwabot.core.designsystem.ArchIconBadge
import com.fatwabot.core.designsystem.BrandCard
import com.fatwabot.core.designsystem.ColorTokens
import com.fatwabot.core.designsystem.DarkTokens
import com.fatwabot.core.designsystem.LightTokens
import com.fatwabot.core.designsystem.LocalReduceMotion
import com.fatwabot.core.designsystem.MotionTokens
import com.fatwabot.core.designsystem.brandScreenBackground
import com.fatwabot.core.designsystem.motionAnimationSpec
import com.fatwabot.core.prayer.PrayerCalculator
import kotlinx.coroutines.flow.collect

/** Compass (docs/features/prayer.md §Qibla) — mirror of iOS QiblaScreen.
 * Falls back to a static bearing display when the device has no rotation
 * sensor (matches iOS's staticFallback for sensor-less devices). */
@Composable
fun QiblaScreen(location: UserLocation, provider: HeadingProviding = SystemHeadingProvider(LocalContext.current)) {
    val bearing = remember(location) { PrayerCalculator().qiblaBearing(location.latitude, location.longitude) }
    var heading by remember { mutableDoubleStateOf(0.0) }
    var accuracy by remember { mutableStateOf(-1.0) }
    val tokens = if (isSystemInDarkTheme()) DarkTokens else LightTokens

    LaunchedEffect(provider) {
        if (provider.supportsHeading) {
            provider.headings().collect {
                heading = it.heading
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
            if (!provider.supportsHeading) {
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
    val needleAngle = bearing - heading
    val reduceMotion = LocalReduceMotion.current
    val animatedAngle by animateFloatAsState(
        targetValue = needleAngle.toFloat(),
        animationSpec = motionAnimationSpec(reduceMotion, MotionTokens.QUICK_MS),
        label = "qibla-needle",
    )

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
                    .rotate((index * 90).toFloat() - heading.toFloat()),
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
        Icon(
            Icons.Filled.NearMe,
            contentDescription = "بوصلة القبلة",
            tint = if (isAligned) tokens.accent else tokens.primary,
            modifier = Modifier.size(64.dp).rotate(animatedAngle),
        )
    }
}

/** Prominent qibla bearing readout below the compass. */
@Composable
private fun BearingReadout(bearing: Double, isAligned: Boolean, tokens: ColorTokens) {
    Text(
        "${bearing.toInt()}°",
        style = MaterialTheme.typography.displaySmall,
        fontWeight = FontWeight.ExtraBold,
        color = if (isAligned) tokens.accent else tokens.primary,
    )
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
        accuracy < 0 -> Icons.Filled.Explore to "جارٍ المعايرة… حرّك جهازك على شكل ٨"
        accuracy > 25 -> Icons.Filled.WarningAmber to "تشويش مغناطيسي — ابتعد عن الأجسام المعدنية"
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
            ArchIconBadge(icon = Icons.Filled.Explore, tokens = tokens)
            Text(
                "اتجاه القبلة: ${bearing.toInt()}°",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                color = tokens.onSurface,
                textAlign = TextAlign.Center,
            )
        }
    }
}
