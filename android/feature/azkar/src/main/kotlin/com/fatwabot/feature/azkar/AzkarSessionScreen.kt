package com.fatwabot.feature.azkar

import androidx.compose.animation.core.animateIntAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.fatwabot.core.content.AzkarCategory
import com.fatwabot.core.content.AzkarItem
import com.fatwabot.core.designsystem.ArchIconBadge
import com.fatwabot.core.designsystem.BrandCard
import com.fatwabot.core.designsystem.ColorTokens
import com.fatwabot.core.designsystem.DarkTokens
import com.fatwabot.core.designsystem.LightTokens
import com.fatwabot.core.designsystem.LocalReduceMotion
import com.fatwabot.core.designsystem.MotionTokens
import com.fatwabot.core.designsystem.RingProgress
import com.fatwabot.core.designsystem.brandScreenBackground
import com.fatwabot.core.designsystem.motionAnimationSpec

/** The reading/counting session (docs/features/azkar.md screen 2) — mirror of
 * iOS AzkarSessionScreen. Completion is a calm confirmation, not a
 * celebratory burst (ADR-0007 tone guidance). */
@Composable
fun AzkarSessionScreen(
    category: AzkarCategory,
    viewModel: AzkarViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val tokens = if (isSystemInDarkTheme()) DarkTokens else LightTokens

    LaunchedEffect(category.id) {
        // The view model is shared across categories, so a finished session must
        // not leak its state onto the next category opened: always re-initialise
        // when this screen is for a different category. (Guarding only on
        // !isSessionComplete made every category opened after a completed one
        // render as already-completed.)
        val current = viewModel.state.value
        if (current.categoryId != category.id ||
            (current.currentItem == null && !current.isSessionComplete)
        ) {
            viewModel.startSession(category.id, category.items)
        }
    }

    Box(modifier = Modifier.fillMaxSize().brandScreenBackground(tokens)) {
        when {
            state.isSessionComplete -> CompletionView(tokens)
            state.currentItem != null -> SessionView(
                item = state.currentItem!!,
                currentCount = state.currentItemCount,
                progress = state.progress,
                tokens = tokens,
                onTick = viewModel::tick,
            )
        }
    }
}

@Composable
private fun SessionView(
    item: AzkarItem,
    currentCount: Int,
    progress: Double,
    tokens: ColorTokens,
    onTick: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        LinearProgressIndicator(
            progress = { progress.toFloat() },
            modifier = Modifier.fillMaxWidth(),
            color = tokens.primary,
            trackColor = tokens.primary.copy(alpha = 0.14f),
        )

        // Arabic dhikr — the prominent centerpiece card.
        BrandCard(tokens = tokens, contentPadding = 22.dp) {
            Column(
                modifier = Modifier.fillMaxWidth(),
                horizontalAlignment = Alignment.End,
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                Text(
                    item.arabicText,
                    style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.Medium,
                    color = tokens.onSurface,
                    textAlign = TextAlign.End,
                    modifier = Modifier.fillMaxWidth(),
                )
                item.translation?.let { translation ->
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(1.dp)
                            .background(tokens.outline.copy(alpha = 0.6f)),
                    )
                    Text(
                        translation,
                        style = MaterialTheme.typography.bodyMedium,
                        color = tokens.onSurfaceSecondary,
                        textAlign = TextAlign.Start,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
                if (item.source.isNotEmpty()) {
                    Text(
                        item.source,
                        style = MaterialTheme.typography.labelSmall,
                        color = tokens.onSurfaceSecondary,
                        textAlign = TextAlign.End,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            }
        }

        // Virtue / benefit note — a subtle, warm accented card.
        item.virtueNote?.let { note ->
            Surface(
                color = tokens.primaryContainer,
                shape = RoundedCornerShape(20.dp),
                modifier = Modifier
                    .fillMaxWidth()
                    .border(1.dp, tokens.accent.copy(alpha = 0.25f), RoundedCornerShape(20.dp)),
            ) {
                Row(
                    modifier = Modifier.padding(16.dp),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Icon(
                        Icons.Filled.AutoAwesome,
                        contentDescription = null,
                        tint = tokens.accent,
                        modifier = Modifier.size(18.dp),
                    )
                    Column(
                        modifier = Modifier.weight(1f),
                        horizontalAlignment = Alignment.End,
                        verticalArrangement = Arrangement.spacedBy(4.dp),
                    ) {
                        Text(
                            "الفائدة",
                            style = MaterialTheme.typography.labelMedium,
                            fontWeight = FontWeight.SemiBold,
                            color = tokens.primary,
                            modifier = Modifier.fillMaxWidth(),
                            textAlign = TextAlign.End,
                        )
                        Text(
                            note,
                            style = MaterialTheme.typography.bodySmall,
                            color = tokens.onSurface,
                            modifier = Modifier.fillMaxWidth(),
                            textAlign = TextAlign.End,
                        )
                    }
                }
            }
        }

        // The counter — large, calm, tappable ring.
        Counter(item = item, currentCount = currentCount, tokens = tokens, onTick = onTick)
    }
}

@Composable
private fun Counter(item: AzkarItem, currentCount: Int, tokens: ColorTokens, onTick: () -> Unit) {
    // Grows with the system font-scale setting (capped) so the primary count
    // text isn't clipped at large accessibility sizes.
    val fontScale = LocalDensity.current.fontScale.coerceIn(1f, 1.6f)
    val reduceMotion = LocalReduceMotion.current
    val fraction = if (item.repeatCount > 0) currentCount.toFloat() / item.repeatCount else 0f
    val animatedCount by animateIntAsState(
        targetValue = currentCount,
        animationSpec = motionAnimationSpec(reduceMotion, MotionTokens.QUICK_MS),
        label = "azkarCount",
    )

    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Center) {
        Surface(
            shape = CircleShape,
            color = Color.Transparent,
            modifier = Modifier
                .size(220.dp * fontScale)
                .semantics(mergeDescendants = true) {
                    contentDescription = "اضغط للعد، $currentCount من ${item.repeatCount}"
                },
            onClick = onTick,
        ) {
            Box(contentAlignment = Alignment.Center) {
                RingProgress(
                    value = fraction,
                    strokeWidth = 12.dp,
                    tokens = tokens,
                    modifier = Modifier.fillMaxSize(),
                )
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(18.dp)
                        .clip(CircleShape)
                        .background(tokens.primary.copy(alpha = 0.06f)),
                )
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    Text(
                        "$animatedCount/${item.repeatCount}",
                        style = MaterialTheme.typography.displaySmall,
                        fontWeight = FontWeight.Bold,
                        color = tokens.primary,
                    )
                    Text(
                        "اضغط للعد",
                        style = MaterialTheme.typography.labelSmall,
                        color = tokens.onSurfaceSecondary,
                    )
                }
            }
        }
    }
}

@Composable
private fun CompletionView(tokens: ColorTokens) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(32.dp)
            .semantics(mergeDescendants = true) {},
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        ArchIconBadge(icon = Icons.Filled.Check, size = 84.dp, tokens = tokens)
        Spacer(Modifier.height(20.dp))
        Text(
            "أتممت الأذكار",
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.SemiBold,
            color = tokens.onSurface,
        )
        Spacer(Modifier.height(6.dp))
        Text(
            "تقبّل الله منك",
            style = MaterialTheme.typography.bodyMedium,
            color = tokens.onSurfaceSecondary,
            textAlign = TextAlign.Center,
        )
    }
}
