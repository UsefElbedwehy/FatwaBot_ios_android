package com.fatwabot.feature.prayer

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Explore
import androidx.compose.material.icons.filled.NearMe
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
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

    LaunchedEffect(provider) {
        if (provider.supportsHeading) {
            provider.headings().collect {
                heading = it.heading
                accuracy = it.accuracy
            }
        }
    }

    Box(
        modifier = Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background),
        contentAlignment = Alignment.Center,
    ) {
        if (!provider.supportsHeading) {
            StaticFallback(bearing)
        } else {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Compass(bearing = bearing, heading = heading)
                AccuracyIndicator(bearing = bearing, accuracy = accuracy)
            }
        }
    }
}

@Composable
private fun Compass(bearing: Double, heading: Double) {
    val needleAngle = bearing - heading
    val isAligned = isAlignedTo(needleAngle)
    val animatedAngle by animateFloatAsState(
        targetValue = needleAngle.toFloat(),
        animationSpec = tween(150),
        label = "qibla-needle",
    )

    Box(
        modifier = Modifier
            .size(260.dp)
            .background(MaterialTheme.colorScheme.surfaceContainer, CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            Icons.Filled.NearMe,
            contentDescription = "بوصلة القبلة",
            tint = if (isAligned) MaterialTheme.colorScheme.secondary else MaterialTheme.colorScheme.primary,
            modifier = Modifier.size(64.dp).rotate(animatedAngle),
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
private fun AccuracyIndicator(bearing: Double, accuracy: Double) {
    val (icon, text) = when {
        accuracy < 0 -> Icons.Filled.Explore to "جارٍ المعايرة… حرّك جهازك على شكل ٨"
        accuracy > 25 -> Icons.Filled.Explore to "تشويش مغناطيسي — ابتعد عن الأجسام المعدنية"
        else -> null to "${bearing.toInt()}°"
    }
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        icon?.let { Icon(it, contentDescription = null, tint = MaterialTheme.colorScheme.onSurfaceVariant) }
        Text(text, color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodyMedium)
    }
}

@Composable
private fun StaticFallback(bearing: Double) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Icon(
            Icons.Filled.Explore,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.primary,
            modifier = Modifier.size(48.dp),
        )
        Text("اتجاه القبلة: ${bearing.toInt()}°", style = MaterialTheme.typography.titleMedium)
    }
}
