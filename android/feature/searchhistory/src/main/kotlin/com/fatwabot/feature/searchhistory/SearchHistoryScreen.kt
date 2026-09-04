package com.fatwabot.feature.searchhistory

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.WifiOff
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Divider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.fatwabot.core.designsystem.BrandCard
import com.fatwabot.core.designsystem.BrandEmptyState
import com.fatwabot.core.designsystem.BrandSectionHeader
import com.fatwabot.core.designsystem.ColorTokens
import com.fatwabot.core.designsystem.DarkTokens
import com.fatwabot.core.designsystem.LightTokens
import com.fatwabot.core.designsystem.brandScreenBackground
import com.fatwabot.feature.searchhistory.R
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import kotlinx.coroutines.launch

/** Search history screen — mirror of iOS SearchHistoryScreen
 * (docs/features/search-history.md). */
@Composable
fun SearchHistoryScreen(viewModel: SearchHistoryViewModel = hiltViewModel()) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val scope = rememberCoroutineScope()
    val tokens = if (isSystemInDarkTheme()) DarkTokens else LightTokens
    var showingClearConfirmation by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) { viewModel.load() }

    val grouped = remember(state.entries) { groupByDay(state.entries) }

    Box(modifier = Modifier.fillMaxSize().brandScreenBackground(tokens)) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp),
        ) {
            if (state.entries.isNotEmpty()) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.End,
                ) {
                    TextButton(onClick = { showingClearConfirmation = true }) {
                        Text(stringResource(R.string.searchhistory_clear_all), color = tokens.primary, fontWeight = FontWeight.SemiBold)
                    }
                }
            }

            state.error?.let { error -> NoticeCard(error, tokens) }

            grouped.forEach { (day, entries) ->
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    BrandSectionHeader(day, icon = Icons.Filled.CalendarMonth, tokens = tokens)
                    BrandCard(tokens = tokens) {
                        Column(modifier = Modifier.fillMaxWidth()) {
                            entries.forEachIndexed { index, entry ->
                                EntryRow(
                                    entry = entry,
                                    tokens = tokens,
                                    onDelete = { scope.launch { viewModel.delete(entry) } },
                                )
                                if (index < entries.size - 1) {
                                    Divider(color = tokens.outline.copy(alpha = 0.4f))
                                }
                            }
                        }
                    }
                }
            }

            if (!state.isLoading && state.entries.isEmpty() && state.error == null) {
                BrandEmptyState(
                    Icons.Filled.History,
                    stringResource(R.string.searchhistory_empty),
                    tokens = tokens,
                )
            }
        }
        if (state.isLoading && state.entries.isEmpty()) {
            CircularProgressIndicator(
                color = tokens.primary,
                modifier = Modifier.align(Alignment.Center),
            )
        }
    }

    if (showingClearConfirmation) {
        AlertDialog(
            onDismissRequest = { showingClearConfirmation = false },
            title = { Text(stringResource(R.string.searchhistory_clear_confirm_title)) },
            confirmButton = {
                TextButton(onClick = {
                    showingClearConfirmation = false
                    scope.launch { viewModel.clearAll() }
                }) { Text(stringResource(R.string.searchhistory_clear_all), color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = { TextButton(onClick = { showingClearConfirmation = false }) { Text(stringResource(R.string.searchhistory_cancel)) } },
        )
    }
}

@Composable
private fun NoticeCard(error: String, tokens: ColorTokens) {
    BrandCard(tokens = tokens) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Icon(Icons.Filled.WifiOff, contentDescription = null, tint = tokens.accent)
            Text(error, style = MaterialTheme.typography.bodySmall, color = tokens.onSurfaceSecondary)
        }
    }
}

@Composable
private fun EntryRow(entry: SearchHistoryEntry, tokens: ColorTokens, onDelete: () -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            Icons.Filled.Search,
            contentDescription = null,
            tint = tokens.onSurfaceSecondary,
            modifier = Modifier.size(18.dp),
        )
        Text(
            entry.queryText,
            modifier = Modifier.weight(1f),
            color = tokens.onSurface,
        )
        Spacer(Modifier.size(0.dp))
        IconButton(onClick = onDelete) {
            Icon(
                Icons.Filled.Close,
                contentDescription = stringResource(R.string.searchhistory_delete),
                tint = tokens.onSurfaceSecondary,
                modifier = Modifier.size(18.dp),
            )
        }
    }
}

private val dayFormatter = DateTimeFormatter.ofLocalizedDate(java.time.format.FormatStyle.MEDIUM).withLocale(java.util.Locale.getDefault())

private fun groupByDay(entries: List<SearchHistoryEntry>): List<Pair<String, List<SearchHistoryEntry>>> {
    val zone = ZoneId.systemDefault()
    return entries
        .sortedByDescending { it.createdAt }
        .groupBy { entry ->
            runCatching { Instant.parse(entry.createdAt).atZone(zone).format(dayFormatter) }.getOrDefault(entry.createdAt)
        }
        .toList()
}
