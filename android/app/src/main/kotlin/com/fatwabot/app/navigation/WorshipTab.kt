package com.fatwabot.app.navigation

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.MenuBook
import androidx.compose.material.icons.filled.AccessTime
import androidx.compose.material.icons.filled.Circle
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.LibraryBooks
import androidx.compose.material.icons.filled.Spa
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.hilt.navigation.compose.hiltViewModel
import com.fatwabot.core.content.AzkarCategory
import com.fatwabot.core.content.Dua
import com.fatwabot.core.content.HadithCollectionSummary
import com.fatwabot.feature.awrad.AwradBoardScreen
import com.fatwabot.feature.azkar.AzkarCategoryListScreen
import com.fatwabot.feature.azkar.AzkarSessionScreen
import com.fatwabot.feature.dua.DuaLibraryScreen
import com.fatwabot.feature.dua.DuaReadingScreen
import com.fatwabot.feature.hadith.HadithCollectionsScreen
import com.fatwabot.feature.hadith.HadithReadingScreen
import com.fatwabot.feature.prayer.PrayerScreen
import com.fatwabot.feature.prayer.PrayerViewModel
import com.fatwabot.feature.tasbeeh.TasbeehScreen

/**
 * M2 interim: lightweight in-tab destination switch. A full feature nav-graph
 * per ADR-0005 (Android dialect) replaces this once Qibla lands as its own
 * row (task 26 wires the complete Worship surface).
 */
private enum class WorshipDestination(val title: String) {
    PRAYER("أوقات الصلاة"),
    TASBEEH("السُّبحة"),
    AZKAR("الأذكار"),
    DUA("الأدعية"),
    AWRAD("أثرك"),
    HADITH("الأحاديث"),
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
        WorshipDestination.AZKAR -> {
            var selectedCategory by remember { mutableStateOf<AzkarCategory?>(null) }
            WorshipDetailScaffold(
                title = selectedCategory?.name ?: WorshipDestination.AZKAR.title,
                onBack = { if (selectedCategory != null) selectedCategory = null else destination = null },
            ) {
                val category = selectedCategory
                if (category == null) {
                    AzkarCategoryListScreen(onCategorySelected = { selectedCategory = it })
                } else {
                    AzkarSessionScreen(category = category)
                }
            }
        }
        WorshipDestination.DUA -> {
            var selectedDua by remember { mutableStateOf<Dua?>(null) }
            WorshipDetailScaffold(
                title = selectedDua?.title ?: WorshipDestination.DUA.title,
                onBack = { if (selectedDua != null) selectedDua = null else destination = null },
            ) {
                val dua = selectedDua
                if (dua == null) {
                    DuaLibraryScreen(onDuaSelected = { selectedDua = it })
                } else {
                    DuaReadingScreen(dua = dua)
                }
            }
        }
        WorshipDestination.AWRAD -> WorshipDetailScaffold(
            title = WorshipDestination.AWRAD.title,
            onBack = { destination = null },
        ) { AwradBoardScreen(viewModel = hiltViewModel()) }
        WorshipDestination.HADITH -> {
            var selectedCollection by remember { mutableStateOf<HadithCollectionSummary?>(null) }
            WorshipDetailScaffold(
                title = selectedCollection?.name ?: WorshipDestination.HADITH.title,
                onBack = { if (selectedCollection != null) selectedCollection = null else destination = null },
            ) {
                val collection = selectedCollection
                if (collection == null) {
                    HadithCollectionsScreen(onCollectionSelected = { selectedCollection = it })
                } else {
                    HadithReadingScreen(slug = collection.slug)
                }
            }
        }
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
                        when (destination) {
                            WorshipDestination.PRAYER -> Icons.Filled.AccessTime
                            WorshipDestination.AZKAR -> Icons.AutoMirrored.Filled.MenuBook
                            WorshipDestination.DUA -> Icons.Filled.Favorite
                            WorshipDestination.AWRAD -> Icons.Filled.Spa
                            WorshipDestination.HADITH -> Icons.Filled.LibraryBooks
                            else -> Icons.Filled.Circle
                        },
                        contentDescription = null,
                    )
                },
                modifier = Modifier.clickable { onSelect(destination) },
            )
            HorizontalDivider()
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
