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
import com.fatwabot.app.BuildConfig
import com.fatwabot.feature.home.HomeHeroContent
import com.fatwabot.feature.home.HomeScreen
import com.fatwabot.feature.home.HomeViewModel
import com.fatwabot.feature.home.QuickAction
import com.fatwabot.feature.prayer.CityPicker
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
    var worshipDestination by rememberSaveable { mutableStateOf<WorshipDestination?>(null) }
    val prayerViewModel: PrayerViewModel = hiltViewModel()
    val prayerState by prayerViewModel.state.collectAsStateWithLifecycle()
    val homeViewModel: HomeViewModel = hiltViewModel()
    val homeState by homeViewModel.state.collectAsStateWithLifecycle()

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions(),
    ) { prayerViewModel.start() }

    LaunchedEffect(Unit) {
        val permissions = buildList {
            add(android.Manifest.permission.ACCESS_COARSE_LOCATION)
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
                add(android.Manifest.permission.POST_NOTIFICATIONS)
            }
        }
        permissionLauncher.launch(permissions.toTypedArray())
        homeViewModel.refresh(BuildConfig.VERSION_NAME, listOf("ar", "en"))
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
                AppTab.HOME -> HomeTab(
                    viewModel = prayerViewModel,
                    state = prayerState,
                    homeState = homeState,
                    onQuickAction = { action ->
                        handleQuickAction(
                            action = action,
                            hasLocation = prayerState.location != null,
                            switchToWorship = { selected = AppTab.WORSHIP },
                            setWorshipDestination = { worshipDestination = it },
                        )
                    },
                )
                AppTab.WORSHIP -> WorshipTab(
                    prayerViewModel = prayerViewModel,
                    destination = worshipDestination,
                    onDestinationChange = { worshipDestination = it },
                )
                AppTab.JOURNEY, AppTab.SETTINGS -> ComingSoon(selected)
            }
        }
    }
}

@Composable
private fun HomeTab(
    viewModel: PrayerViewModel,
    state: PrayerViewModel.UiState,
    homeState: HomeViewModel.UiState,
    onQuickAction: (QuickAction) -> Unit,
) {
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
        layout = homeState.layout,
        askEnabled = homeState.askEnabled,
        hero = hero,
        formatTime = ::formatTime,
        prayerTitle = { stringResource(it.titleRes()) },
        onQuickAction = onQuickAction,
    )
}

/** Deep-links from Home's quick actions (task 26): switches to Worship and
 * pushes the target screen directly — no extra tap required. `HISTORY`
 * (Search History) has no content until AI Search ships (M5+), so it is
 * intentionally inert rather than routing to a hollow screen. */
private fun handleQuickAction(
    action: QuickAction,
    hasLocation: Boolean,
    switchToWorship: () -> Unit,
    setWorshipDestination: (WorshipDestination?) -> Unit,
) {
    when (action) {
        QuickAction.QIBLA -> {
            if (!hasLocation) {
                switchToWorship()
                return
            }
            setWorshipDestination(WorshipDestination.QIBLA)
        }
        QuickAction.TASBEEH -> setWorshipDestination(WorshipDestination.TASBEEH)
        QuickAction.AZKAR -> setWorshipDestination(WorshipDestination.AZKAR)
        QuickAction.HISTORY -> return
    }
    switchToWorship()
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
