package com.fatwabot.app.navigation

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.AccessTime
import androidx.compose.material.icons.filled.Circle
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.fatwabot.feature.prayer.PrayerScreen
import com.fatwabot.feature.prayer.PrayerViewModel
import com.fatwabot.feature.tasbeeh.TasbeehScreen

/**
 * M2 interim: lightweight in-tab destination switch. A full feature nav-graph
 * per ADR-0005 (Android dialect) replaces this once Azkar/Dua/Hadith/Qibla
 * land (task 26 wires the complete Worship surface).
 */
private enum class WorshipDestination(val title: String) {
    PRAYER("أوقات الصلاة"),
    TASBEEH("السُّبحة"),
}

@Composable
fun WorshipTab(prayerViewModel: PrayerViewModel) {
    var destination by rememberSaveable { mutableStateOf<WorshipDestination?>(null) }

    when (destination) {
        null -> WorshipMenu(onSelect = { destination = it })
        WorshipDestination.PRAYER -> WorshipDetailScaffold(
            title = WorshipDestination.PRAYER.title,
            onBack = { destination = null },
        ) { PrayerScreen(prayerViewModel) }
        WorshipDestination.TASBEEH -> WorshipDetailScaffold(
            title = WorshipDestination.TASBEEH.title,
            onBack = { destination = null },
        ) { TasbeehScreen(viewModel = hiltViewModel()) }
    }
}

@Composable
private fun WorshipMenu(onSelect: (WorshipDestination) -> Unit) {
    LazyColumn(modifier = Modifier.fillMaxSize()) {
        items(WorshipDestination.entries) { destination ->
            ListItem(
                headlineContent = { Text(destination.title) },
                leadingContent = {
                    Icon(
                        if (destination == WorshipDestination.PRAYER) Icons.Filled.AccessTime else Icons.Filled.Circle,
                        contentDescription = null,
                    )
                },
                modifier = Modifier.clickable { onSelect(destination) },
            )
            HorizontalDivider()
        }
        item {
            Text(
                "الأذكار والأدعية والأحاديث — قريباً إن شاء الله",
                modifier = Modifier.padding(16.dp),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
private fun WorshipDetailScaffold(title: String, onBack: () -> Unit, content: @Composable () -> Unit) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(title) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = null)
                    }
                },
            )
        },
    ) { padding ->
        Box(modifier = Modifier.padding(padding)) {
            content()
        }
    }
}
