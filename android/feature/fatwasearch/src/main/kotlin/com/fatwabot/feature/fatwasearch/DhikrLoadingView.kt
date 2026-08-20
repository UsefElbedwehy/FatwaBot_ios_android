package com.fatwabot.feature.fatwasearch

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.fatwabot.core.designsystem.BrandMark
import com.fatwabot.core.designsystem.ColorTokens
import kotlinx.coroutines.delay

/** Loading state for an in-flight `/v1/search` answer: the brand mark with a
 * rotating dhikr line underneath, covering LLM latency with something worth
 * reading rather than a bare spinner (per the client's reference app).
 *
 * The four phrases are fixed Arabic dhikr text, not localized strings — like
 * the Tasbeeh presets, religious wording stays Arabic regardless of the
 * device locale. Mirror of iOS DhikrLoadingView. */
@Composable
fun DhikrLoadingView(tokens: ColorTokens, modifier: Modifier = Modifier) {
    val phrases = remember { listOf("سبحان الله", "الحمد لله", "الله أكبر", "لا إله إلا الله") }
    var index by remember { mutableIntStateOf(0) }

    LaunchedEffect(Unit) {
        while (true) {
            delay(1600)
            index = (index + 1) % phrases.size
        }
    }

    val transition = rememberInfiniteTransition(label = "dhikr-pulse")
    val pulse by transition.animateFloat(
        initialValue = 0.55f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(1100, easing = LinearEasing),
            repeatMode = RepeatMode.Reverse,
        ),
        label = "dhikr-pulse-value",
    )

    androidx.compose.foundation.layout.Column(
        modifier = modifier.fillMaxWidth().padding(vertical = 56.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = androidx.compose.foundation.layout.Arrangement.spacedBy(20.dp),
    ) {
        BrandMark(
            color = tokens.primary,
            modifier = Modifier
                .width(64.dp)
                .height(90.dp)
                .graphicsLayer(alpha = pulse, scaleX = 0.94f + 0.06f * pulse, scaleY = 0.94f + 0.06f * pulse),
        )
        Text(
            phrases[index],
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
            color = tokens.primary,
        )
    }
}
