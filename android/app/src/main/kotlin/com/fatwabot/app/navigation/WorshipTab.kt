package com.fatwabot.app.navigation

import androidx.activity.compose.BackHandler
import androidx.compose.material.icons.automirrored.filled.TrendingUp
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.MenuBook
import androidx.compose.material.icons.filled.AccessTime
import androidx.compose.material.icons.filled.Circle
import androidx.compose.material.icons.filled.Explore
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.LibraryBooks
import androidx.compose.material.icons.filled.Spa
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.annotation.StringRes
import androidx.compose.runtime.Composable
import androidx.compose.ui.res.stringResource
import com.fatwabot.app.R
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
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
import com.fatwabot.feature.prayer.QiblaScreen
import com.fatwabot.feature.tasbeeh.TasbeehScreen

/**
 * M2: lightweight in-tab destination switch. A full feature nav-graph per
 * ADR-0005 (Android dialect) is a future refactor once this list stops
 * growing. `destination` is hoisted to RootScaffold so Home's quick actions
 * (task 26) can deep-link directly into a screen, not just the tab.
 */
/** Maps a deep link onto the worship stack. `HOME` has no worship destination
 * and is handled by the caller. */
fun com.fatwabot.core.common.DeepLink.worshipDestination(): WorshipDestination? = when (this) {
    com.fatwabot.core.common.DeepLink.PRAYER -> WorshipDestination.PRAYER
    com.fatwabot.core.common.DeepLink.QIBLA -> WorshipDestination.QIBLA
    com.fatwabot.core.common.DeepLink.TASBEEH -> WorshipDestination.TASBEEH
    com.fatwabot.core.common.DeepLink.AZKAR -> WorshipDestination.AZKAR
    com.fatwabot.core.common.DeepLink.DUA -> WorshipDestination.DUA
    com.fatwabot.core.common.DeepLink.AWRAD -> WorshipDestination.AWRAD
    com.fatwabot.core.common.DeepLink.HADITH -> WorshipDestination.HADITH
    com.fatwabot.core.common.DeepLink.JOURNEY -> WorshipDestination.JOURNEY
    com.fatwabot.core.common.DeepLink.HOME -> null
}

enum class WorshipDestination(@StringRes val titleRes: Int) {
    PRAYER(R.string.worship_prayer_times),
    QIBLA(R.string.worship_qibla),
    TASBEEH(R.string.worship_tasbeeh),
    AZKAR(R.string.worship_azkar),
    DUA(R.string.worship_dua),
    AWRAD(R.string.worship_awrad),
    HADITH(R.string.worship_hadith),
    JOURNEY(R.string.tab_journey),
}

@Composable
fun WorshipTab(
    prayerViewModel: PrayerViewModel,
    destination: WorshipDestination?,
    onDestinationChange: (WorshipDestination?) -> Unit,
) {
    val prayerState by prayerViewModel.state.collectAsStateWithLifecycle()

    when (destination) {
        null -> WorshipMenu(
            hasLocation = prayerState.location != null,
            onSelect = onDestinationChange,
        )
        WorshipDestination.PRAYER -> WorshipDetailScaffold(
            title = stringResource(WorshipDestination.PRAYER.titleRes),
            onBack = { onDestinationChange(null) },
        ) { PrayerScreen(prayerViewModel) }
        WorshipDestination.QIBLA -> WorshipDetailScaffold(
            title = stringResource(WorshipDestination.QIBLA.titleRes),
            onBack = { onDestinationChange(null) },
        ) {
            prayerState.location?.let { location -> QiblaScreen(location = location) }
        }
        WorshipDestination.TASBEEH -> WorshipDetailScaffold(
            title = stringResource(WorshipDestination.TASBEEH.titleRes),
            onBack = { onDestinationChange(null) },
        ) { TasbeehScreen(viewModel = hiltViewModel()) }
        WorshipDestination.AZKAR -> {
            var selectedCategory by remember { mutableStateOf<AzkarCategory?>(null) }
            WorshipDetailScaffold(
                title = selectedCategory?.name ?: stringResource(WorshipDestination.AZKAR.titleRes),
                onBack = { if (selectedCategory != null) selectedCategory = null else onDestinationChange(null) },
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
                title = selectedDua?.title ?: stringResource(WorshipDestination.DUA.titleRes),
                onBack = { if (selectedDua != null) selectedDua = null else onDestinationChange(null) },
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
            title = stringResource(WorshipDestination.AWRAD.titleRes),
            onBack = { onDestinationChange(null) },
        ) { AwradBoardScreen(viewModel = hiltViewModel()) }
        WorshipDestination.HADITH -> {
            var selectedCollection by remember { mutableStateOf<HadithCollectionSummary?>(null) }
            WorshipDetailScaffold(
                title = selectedCollection?.name ?: stringResource(WorshipDestination.HADITH.titleRes),
                onBack = { if (selectedCollection != null) selectedCollection = null else onDestinationChange(null) },
            ) {
                val collection = selectedCollection
                if (collection == null) {
                    HadithCollectionsScreen(onCollectionSelected = { selectedCollection = it })
                } else {
                    HadithReadingScreen(slug = collection.slug)
                }
            }
        }
        WorshipDestination.JOURNEY -> {
            BackHandler { onDestinationChange(null) }
            JourneyTab()
        }
    }
}

private fun iconFor(destination: WorshipDestination) = when (destination) {
    WorshipDestination.PRAYER -> Icons.Filled.AccessTime
    WorshipDestination.QIBLA -> Icons.Filled.Explore
    WorshipDestination.AZKAR -> Icons.AutoMirrored.Filled.MenuBook
    WorshipDestination.DUA -> Icons.Filled.Favorite
    WorshipDestination.AWRAD -> Icons.Filled.Spa
    WorshipDestination.HADITH -> Icons.Filled.LibraryBooks
    WorshipDestination.JOURNEY -> Icons.AutoMirrored.Filled.TrendingUp
    else -> Icons.Filled.Circle
}

@Composable
private fun WorshipMenu(hasLocation: Boolean, onSelect: (WorshipDestination) -> Unit) {
    val visible = WorshipDestination.entries.filter { it != WorshipDestination.QIBLA || hasLocation }
    LazyVerticalGrid(
        columns = GridCells.Fixed(2),
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        horizontalArrangement = androidx.compose.foundation.layout.Arrangement.spacedBy(16.dp),
        verticalArrangement = androidx.compose.foundation.layout.Arrangement.spacedBy(16.dp),
    ) {
        items(visible) { destination ->
            WorshipTile(destination = destination, onClick = { onSelect(destination) })
        }
    }
}

@Composable
private fun WorshipTile(destination: WorshipDestination, onClick: () -> Unit) {
    Surface(
        shape = RoundedCornerShape(20.dp),
        color = MaterialTheme.colorScheme.surfaceContainer,
        modifier = Modifier.aspectRatio(1f).clickable(onClick = onClick),
    ) {
        Column(
            modifier = Modifier.fillMaxSize().padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = androidx.compose.foundation.layout.Arrangement.Center,
        ) {
            Box(
                modifier = Modifier
                    .size(64.dp)
                    .background(MaterialTheme.colorScheme.primaryContainer, RoundedCornerShape(18.dp)),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    iconFor(destination),
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(30.dp),
                )
            }
            androidx.compose.foundation.layout.Spacer(modifier = Modifier.padding(top = 12.dp))
            Text(
                stringResource(destination.titleRes),
                style = MaterialTheme.typography.bodyMedium,
                textAlign = TextAlign.Center,
                maxLines = 2,
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
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.common_back))
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
