package com.fatwabot.feature.tasbeeh

import androidx.compose.animation.core.animateIntAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.History
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.fatwabot.feature.tasbeeh.R
import com.fatwabot.core.designsystem.BrandCard
import com.fatwabot.core.designsystem.BrandEmptyState
import com.fatwabot.core.designsystem.ColorTokens
import com.fatwabot.core.designsystem.DarkTokens
import com.fatwabot.core.designsystem.InfoNotice
import com.fatwabot.core.designsystem.LightTokens
import com.fatwabot.core.designsystem.LocalReduceMotion
import com.fatwabot.core.designsystem.MotionTokens
import com.fatwabot.core.designsystem.RingProgress
import com.fatwabot.core.designsystem.brandScreenBackground
import com.fatwabot.core.designsystem.motionAnimationSpec

/**
 * @param notice Optional advisory note shown above the counter. Passed in rather
 *   than read here so this feature module stays free of config/network knowledge
 *   (ADR-0010) — the composition root resolves it from the server string pack
 *   with a bundled fallback, so it can change without an app release.
 */
@Composable
fun TasbeehScreen(
    viewModel: TasbeehViewModel = hiltViewModel(),
    notice: String? = null,
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val tokens = if (isSystemInDarkTheme()) DarkTokens else LightTokens
    var showResetConfirm by remember { mutableStateOf(false) }
    var showHistory by remember { mutableStateOf(false) }

    Box(modifier = Modifier.fillMaxSize().brandScreenBackground(tokens)) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(20.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(24.dp),
        ) {
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                IconButton(onClick = { showHistory = true }) {
                    Icon(Icons.Filled.History, contentDescription = stringResource(R.string.tasbeeh_history_title), tint = tokens.primary)
                }
            }
            if (!notice.isNullOrBlank()) {
                InfoNotice(notice, tokens = tokens)
            }
            PresetChips(state, viewModel, tokens)
            TapTarget(state, viewModel, tokens)
            ControlsRow(
                state = state,
                tokens = tokens,
                onResetTap = { if (state.count > 0) showResetConfirm = true else viewModel.reset() },
                onTargetChange = viewModel::changeTarget,
                onComplete = viewModel::completeSet,
            )
        }
    }

    if (showResetConfirm) {
        AlertDialog(
            onDismissRequest = { showResetConfirm = false },
            title = { Text(stringResource(R.string.tasbeeh_reset_confirm)) },
            confirmButton = {
                TextButton(onClick = { viewModel.reset(); showResetConfirm = false }) { Text(stringResource(R.string.tasbeeh_reset_confirm_action)) }
            },
            dismissButton = { TextButton(onClick = { showResetConfirm = false }) { Text(stringResource(R.string.tasbeeh_cancel)) } },
        )
    }

    if (showHistory) {
        TasbeehHistorySheet(state = state, tokens = tokens, onDismiss = { showHistory = false })
    }
}

@Composable
private fun PresetChips(state: TasbeehViewModel.UiState, viewModel: TasbeehViewModel, tokens: ColorTokens) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Row(modifier = Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            DhikrPreset.bundled.forEach { preset ->
                Chip(preset.arabicText, state.selectedPreset.id == preset.id, tokens) { viewModel.select(preset) }
            }
            Chip(stringResource(R.string.tasbeeh_custom), state.selectedPreset.id == DhikrPreset.CUSTOM.id, tokens) { viewModel.select(DhikrPreset.CUSTOM) }
        }
        if (state.selectedPreset.id == DhikrPreset.CUSTOM.id) {
            OutlinedTextField(
                value = state.customText,
                onValueChange = viewModel::updateCustomText,
                placeholder = { Text(stringResource(R.string.tasbeeh_custom_placeholder)) },
                modifier = Modifier.fillMaxWidth(),
            )
        }
    }
}

@Composable
private fun Chip(title: String, isSelected: Boolean, tokens: ColorTokens, onClick: () -> Unit) {
    Surface(
        shape = CircleShape,
        color = if (isSelected) tokens.primary else tokens.primaryContainer,
        modifier = Modifier,
        onClick = onClick,
    ) {
        Text(
            title,
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 8.dp),
            style = MaterialTheme.typography.labelLarge,
            fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
            color = if (isSelected) tokens.onPrimary else tokens.primary,
        )
    }
}

/**
 * The centerpiece: a large circular tap target with a maroon→gold progress ring
 * around the live count toward the target, and the selected dhikr beneath it.
 */
@Composable
private fun TapTarget(state: TasbeehViewModel.UiState, viewModel: TasbeehViewModel, tokens: ColorTokens) {
    // Grows with the system font-scale setting (capped) so the primary count
    // text isn't clipped at large accessibility text sizes.
    val fontScale = LocalDensity.current.fontScale.coerceIn(1f, 1.6f)
    val reduceMotion = LocalReduceMotion.current
    val animatedCount by animateIntAsState(
        targetValue = state.count,
        animationSpec = motionAnimationSpec(reduceMotion, MotionTokens.QUICK_MS),
        label = "tasbeehCount",
    )
    val fraction = if (state.target > 0) (state.count.toFloat() / state.target).coerceIn(0f, 1f) else 0f

    Surface(
        shape = CircleShape,
        color = tokens.surfaceElevated,
        modifier = Modifier
            .size(300.dp * fontScale)
            .semantics(mergeDescendants = true) {},
        onClick = viewModel::increment,
    ) {
        Box(contentAlignment = Alignment.Center) {
            RingProgress(
                value = fraction,
                strokeWidth = 12.dp,
                tokens = tokens,
                modifier = Modifier.fillMaxSize().padding(6.dp),
            )
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(22.dp)
                    .clip(CircleShape)
                    .background(
                        Brush.linearGradient(listOf(tokens.primaryContainer, tokens.surfaceElevated)),
                    ),
            )
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier.padding(28.dp),
            ) {
                Text(
                    "$animatedCount",
                    style = MaterialTheme.typography.displayLarge,
                    fontWeight = FontWeight.Bold,
                    color = tokens.primary,
                )
                Text(
                    state.displayText,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = tokens.onSurface,
                    textAlign = TextAlign.Center,
                    maxLines = 2,
                    modifier = Modifier.padding(horizontal = 24.dp),
                )
                Text(
                    stringResource(R.string.tasbeeh_target, state.target),
                    style = MaterialTheme.typography.bodyMedium,
                    color = tokens.onSurfaceSecondary,
                )
            }
        }
    }
}

@Composable
private fun ControlsRow(
    state: TasbeehViewModel.UiState,
    tokens: ColorTokens,
    onResetTap: () -> Unit,
    onTargetChange: (Int) -> Unit,
    onComplete: () -> Unit,
) {
    var targetMenuOpen by remember { mutableStateOf(false) }
    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        OutlinedButton(onClick = onResetTap, modifier = Modifier.weight(1f)) { Text(stringResource(R.string.tasbeeh_reset)) }
        Column(modifier = Modifier.weight(1f)) {
            OutlinedButton(onClick = { targetMenuOpen = true }, modifier = Modifier.fillMaxWidth()) {
                Text(stringResource(R.string.tasbeeh_target, state.target))
            }
            DropdownMenu(expanded = targetMenuOpen, onDismissRequest = { targetMenuOpen = false }) {
                DhikrPreset.commonTargets.forEach { value ->
                    DropdownMenuItem(text = { Text("$value") }, onClick = { onTargetChange(value); targetMenuOpen = false })
                }
            }
        }
        Button(onClick = onComplete, enabled = state.count > 0, modifier = Modifier.weight(1f)) {
            Text(stringResource(R.string.tasbeeh_complete_set))
        }
    }
}

@Composable
private fun TasbeehHistorySheet(state: TasbeehViewModel.UiState, tokens: ColorTokens, onDismiss: () -> Unit) {
    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.tasbeeh_done)) } },
        title = { Text(stringResource(R.string.tasbeeh_history_title)) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                    StatCard(state.stats.totalCount, stringResource(R.string.tasbeeh_total), tokens, Modifier.weight(1f))
                    StatCard(state.stats.setsCompleted, stringResource(R.string.tasbeeh_sets_completed), tokens, Modifier.weight(1f))
                }
                if (state.history.isEmpty()) {
                    BrandEmptyState(Icons.Filled.History, stringResource(R.string.tasbeeh_history_empty), tokens = tokens)
                } else {
                    BrandCard(tokens = tokens) {
                        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            state.history.sortedByDescending { it.completedAtEpochSeconds }.forEach { entry ->
                                Row(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .semantics(mergeDescendants = true) {},
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                ) {
                                    Text(entry.customText ?: entry.presetId ?: "", color = tokens.onSurface)
                                    Text("${entry.actualCount}/${entry.target}", color = tokens.onSurfaceSecondary)
                                }
                            }
                        }
                    }
                }
            }
        },
    )
}

@Composable
private fun StatCard(value: Int, label: String, tokens: ColorTokens, modifier: Modifier = Modifier) {
    Surface(
        shape = RoundedCornerShape(20.dp),
        color = tokens.surfaceElevated,
        modifier = modifier.semantics(mergeDescendants = true) {},
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(4.dp),
            modifier = Modifier.fillMaxWidth().padding(vertical = 20.dp),
        ) {
            Text(
                "$value",
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.ExtraBold,
                color = tokens.primary,
            )
            Text(label, style = MaterialTheme.typography.labelMedium, color = tokens.onSurfaceSecondary)
        }
    }
}
