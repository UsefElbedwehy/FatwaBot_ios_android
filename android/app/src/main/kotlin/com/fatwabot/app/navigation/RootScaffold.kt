package com.fatwabot.app.navigation

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.ui.res.painterResource
import com.fatwabot.app.R
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Alignment
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import com.fatwabot.core.designsystem.BrandMark
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
    }

    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        bottomBar = { FatwaBottomBar(selected = selected, onSelect = { selected = it }) },
    ) { padding ->
        Box(modifier = Modifier.fillMaxSize().padding(padding)) {
            when (selected) {
                AppTab.HOME -> SearchHome()
                AppTab.WORSHIP -> WorshipTab(
                    prayerViewModel = prayerViewModel,
                    destination = worshipDestination,
                    onDestinationChange = { worshipDestination = it },
                )
                AppTab.SETTINGS -> SettingsScreen(prayerViewModel = prayerViewModel)
            }
        }
    }
}

/** Custom floating bottom bar (client redesign): Worship (left) · Home (raised
 * center) · Settings (right). Journey lives in the Worship grid now. Forced LTR
 * so placement matches the mockup in both languages. */
@Composable
private fun FatwaBottomBar(selected: AppTab, onSelect: (AppTab) -> Unit) {
    val cs = MaterialTheme.colorScheme
    CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
        Row(
            modifier = Modifier
                .padding(horizontal = 16.dp, vertical = 8.dp)
                .fillMaxWidth()
                .clip(RoundedCornerShape(30.dp))
                .background(cs.surface)
                .padding(horizontal = 22.dp, vertical = 8.dp),
            verticalAlignment = Alignment.Bottom,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            BarItem(AppTab.WORSHIP, selected, cs, Modifier.weight(1f)) { onSelect(it) }
            HomeBarItem(selected == AppTab.HOME, cs, Modifier.weight(1f)) { onSelect(AppTab.HOME) }
            BarItem(AppTab.SETTINGS, selected, cs, Modifier.weight(1f)) { onSelect(it) }
        }
    }
}

@Composable
private fun BarItem(tab: AppTab, selected: AppTab, cs: androidx.compose.material3.ColorScheme, modifier: Modifier, onClick: (AppTab) -> Unit) {
    val active = tab == selected
    val tint = if (active) cs.primary else cs.onSurfaceVariant
    Column(
        modifier = modifier.clickable { onClick(tab) }.padding(vertical = 6.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Icon(tab.icon, contentDescription = null, tint = tint)
        Text(stringResource(tab.titleRes), style = MaterialTheme.typography.labelSmall, color = tint)
    }
}

@Composable
private fun HomeBarItem(active: Boolean, cs: androidx.compose.material3.ColorScheme, modifier: Modifier, onClick: () -> Unit) {
    Column(
        modifier = modifier.clickable(onClick = onClick).offset(y = (-14).dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Box(
            modifier = Modifier.size(60.dp).clip(CircleShape).background(cs.surface),
            contentAlignment = Alignment.Center,
        ) {
            Image(
                painter = painterResource(R.drawable.fatwabot_logo),
                contentDescription = null,
                modifier = Modifier.width(26.dp).height(34.dp),
            )
        }
        Text(
            stringResource(AppTab.HOME.titleRes),
            style = MaterialTheme.typography.labelSmall,
            color = if (active) cs.primary else cs.onSurfaceVariant,
            modifier = Modifier.padding(top = 4.dp),
        )
    }
}
