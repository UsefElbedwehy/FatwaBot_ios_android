package com.fatwabot.feature.tasbeeh

import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
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
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle

@Composable
fun TasbeehScreen(viewModel: TasbeehViewModel = hiltViewModel()) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    var showResetConfirm by remember { mutableStateOf(false) }
    var showHistory by remember { mutableStateOf(false) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
            IconButton(onClick = { showHistory = true }) {
                Icon(Icons.Filled.History, contentDescription = "Tasbeeh history")
            }
        }
        Text(
            "${state.count}",
            style = MaterialTheme.typography.displayLarge,
            color = MaterialTheme.colorScheme.primary,
        )
        Text(
            "الهدف: ${state.target}",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(Modifier.size(16.dp))
        PresetChips(state, viewModel)
        Spacer(Modifier.size(24.dp))
        TapTarget(state, viewModel)
        Spacer(Modifier.size(24.dp))
        ControlsRow(
            state = state,
            onResetTap = { if (state.count > 0) showResetConfirm = true else viewModel.reset() },
            onTargetChange = viewModel::changeTarget,
            onComplete = viewModel::completeSet,
        )
    }

    if (showResetConfirm) {
        AlertDialog(
            onDismissRequest = { showResetConfirm = false },
            title = { Text("هل تريد إعادة التعيين؟ سيتم فقدان العدد الحالي") },
            confirmButton = {
                TextButton(onClick = { viewModel.reset(); showResetConfirm = false }) { Text("إعادة التعيين") }
            },
            dismissButton = { TextButton(onClick = { showResetConfirm = false }) { Text("إلغاء") } },
        )
    }

    if (showHistory) {
        TasbeehHistorySheet(state = state, onDismiss = { showHistory = false })
    }
}

@Composable
private fun PresetChips(state: TasbeehViewModel.UiState, viewModel: TasbeehViewModel) {
    Row(modifier = Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        DhikrPreset.bundled.forEach { preset ->
            Chip(preset.arabicText, state.selectedPreset.id == preset.id) { viewModel.select(preset) }
        }
        Chip("مخصص", state.selectedPreset.id == DhikrPreset.CUSTOM.id) { viewModel.select(DhikrPreset.CUSTOM) }
    }
    if (state.selectedPreset.id == DhikrPreset.CUSTOM.id) {
        OutlinedTextField(
            value = state.customText,
            onValueChange = viewModel::updateCustomText,
            placeholder = { Text("اكتب ذكرك الخاص") },
            modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
        )
    }
}

@Composable
private fun Chip(title: String, isSelected: Boolean, onClick: () -> Unit) {
    Surface(
        shape = CircleShape,
        color = if (isSelected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.primaryContainer,
        modifier = Modifier,
        onClick = onClick,
    ) {
        Text(
            title,
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 8.dp),
            color = if (isSelected) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.primary,
        )
    }
}

@Composable
private fun TapTarget(state: TasbeehViewModel.UiState, viewModel: TasbeehViewModel) {
    Surface(
        shape = CircleShape,
        color = MaterialTheme.colorScheme.primary,
        modifier = Modifier.size(220.dp),
        onClick = viewModel::increment,
    ) {
        Column(
            modifier = Modifier.fillMaxSize(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            Text(
                state.displayText,
                style = MaterialTheme.typography.titleLarge,
                color = MaterialTheme.colorScheme.onPrimary,
                modifier = Modifier.padding(16.dp),
            )
        }
    }
}

@Composable
private fun ControlsRow(
    state: TasbeehViewModel.UiState,
    onResetTap: () -> Unit,
    onTargetChange: (Int) -> Unit,
    onComplete: () -> Unit,
) {
    var targetMenuOpen by remember { mutableStateOf(false) }
    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        OutlinedButton(onClick = onResetTap, modifier = Modifier.weight(1f)) { Text("إعادة") }
        Column(modifier = Modifier.weight(1f)) {
            OutlinedButton(onClick = { targetMenuOpen = true }, modifier = Modifier.fillMaxWidth()) {
                Text("الهدف: ${state.target}")
            }
            DropdownMenu(expanded = targetMenuOpen, onDismissRequest = { targetMenuOpen = false }) {
                DhikrPreset.commonTargets.forEach { value ->
                    DropdownMenuItem(text = { Text("$value") }, onClick = { onTargetChange(value); targetMenuOpen = false })
                }
            }
        }
        Button(onClick = onComplete, enabled = state.count > 0, modifier = Modifier.weight(1f)) {
            Text("إنهاء الجولة")
        }
    }
}

@Composable
private fun TasbeehHistorySheet(state: TasbeehViewModel.UiState, onDismiss: () -> Unit) {
    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = { TextButton(onClick = onDismiss) { Text("تم") } },
        title = { Text("سجل التسبيح") },
        text = {
            Column {
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceEvenly) {
                    StatColumn(state.stats.totalCount, "الإجمالي")
                    StatColumn(state.stats.setsCompleted, "الجولات المكتملة")
                }
                Spacer(Modifier.size(12.dp))
                LazyColumn {
                    items(state.history.sortedByDescending { it.completedAtEpochSeconds }) { entry ->
                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text(entry.customText ?: entry.presetId ?: "")
                            Text("${entry.actualCount}/${entry.target}")
                        }
                    }
                }
            }
        },
    )
}

@Composable
private fun StatColumn(value: Int, label: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text("$value", style = MaterialTheme.typography.headlineSmall)
        Text(label, style = MaterialTheme.typography.labelSmall)
    }
}
