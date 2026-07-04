package com.fatwabot.app.navigation

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.fatwabot.feature.home.HomeHeroContent
import com.fatwabot.feature.home.HomeScreen
import com.fatwabot.feature.prayer.CityPicker
import com.fatwabot.feature.prayer.PrayerScreen
import com.fatwabot.feature.prayer.PrayerViewModel
import com.fatwabot.feature.prayer.formatTime
import com.fatwabot.feature.prayer.titleRes

/**
 * M1 shell: 4 tabs with Home (server-layout sections) and Worship→Prayer live;
 * feature nav-graphs replace inline composition as features multiply (ADR-0005).
 */
@Composable
fun RootScaffold() {
    var selected by rememberSaveable { mutableStateOf(AppTab.HOME) }
    val prayerViewModel: PrayerViewModel = hiltViewModel()
    val prayerState by prayerViewModel.state.collectAsStateWithLifecycle()

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { prayerViewModel.start() }

    LaunchedEffect(Unit) {
        permissionLauncher.launch(android.Manifest.permission.ACCESS_COARSE_LOCATION)
    }

    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        bottomBar = {
            NavigationBar {
                AppTab.entries.forEach { tab ->
                    NavigationBarItem(
                        selected = tab == selected,
                        onClick = { selected = tab },
                        icon = { Icon(tab.icon, contentDescription = null) },
                        label = { Text(stringResource(tab.titleRes)) },
                    )
                }
            }
        },
    ) { padding ->
        Box(modifier = Modifier.fillMaxSize().padding(padding)) {
            when (selected) {
                AppTab.HOME -> HomeTab(prayerViewModel, prayerState)
                AppTab.WORSHIP -> PrayerScreen(prayerViewModel)
                AppTab.JOURNEY, AppTab.SETTINGS -> ComingSoon(selected)
            }
        }
    }
}

@Composable
private fun HomeTab(viewModel: PrayerViewModel, state: PrayerViewModel.UiState) {
    if (state.needsLocation) {
        CityPicker(onSelect = viewModel::selectCity)
        return
    }
    val hero = state.nextPrayer?.let { next ->
        state.today?.let { today ->
            HomeHeroContent(
                next = next,
                today = today,
                hijri = state.hijri,
                locationName = state.location?.name,
            )
        }
    }
    HomeScreen(
        layout = null, // server layout arrives with Android ConfigSync (follow-up in this milestone)
        askEnabled = false,
        hero = hero,
        formatTime = ::formatTime,
        prayerTitle = { stringResource(it.titleRes()) },
    )
}

@Composable
private fun ComingSoon(tab: AppTab) {
    Column(
        modifier = Modifier.fillMaxSize(),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Icon(tab.icon, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
        Text(
            stringResource(com.fatwabot.app.R.string.common_coming_soon),
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}
