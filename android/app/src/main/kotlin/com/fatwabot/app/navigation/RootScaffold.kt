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
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.GridView
import androidx.compose.material.icons.filled.MoreHoriz
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Alignment
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import kotlin.math.abs
import kotlin.math.cos
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
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

/** Maroon cradle nav (client mockup, design/homeDesign.jpeg): a full-bleed maroon
 * band with a scooped top edge cradling a raised cream Home button (mihrab logo +
 * "الرئيسية"). A "⋯" (Settings) sits left, a 2×2 grid (Worship) right — white on
 * maroon. Forced LTR so placement matches the mockup in both languages. */
@Composable
private fun FatwaBottomBar(selected: AppTab, onSelect: (AppTab) -> Unit) {
    val cs = MaterialTheme.colorScheme
    val bottomInset = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    val barHeight = 108.dp
    CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(barHeight + bottomInset)
                .drawBehind {
                    val path = cradlePath(size, 54.dp.toPx(), 18.dp.toPx(), 22.dp.toPx())
                    drawPath(path, cs.primary)
                    drawPath(path, Color.White.copy(alpha = 0.16f), style = Stroke(width = 2.dp.toPx()))
                },
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(barHeight)
                    .align(Alignment.TopCenter)
                    .offset(y = 6.dp)
                    .padding(horizontal = 40.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                SideItem(AppTab.SETTINGS, Icons.Filled.MoreHoriz, selected, cs) { onSelect(AppTab.SETTINGS) }
                SideItem(AppTab.WORSHIP, Icons.Filled.GridView, selected, cs) { onSelect(AppTab.WORSHIP) }
            }
            HomeCircle(cs, Modifier.align(Alignment.TopCenter).offset(y = (-26).dp)) { onSelect(AppTab.HOME) }
        }
    }
}

/** Maroon band path: a smooth cradle. Two soft shoulders peak just outside the
 * Home circle, the center dips under it, and the top eases down to the screen
 * edges — sampled from a cosine so every junction meets with a horizontal
 * tangent (no cusps or seams). Mirrors iOS NavCradleShape. */
private fun cradlePath(size: Size, shoulderHalf: Float, valleyDip: Float, edgeDrop: Float): Path {
    val w = size.width
    val top = 0f
    val cx = w / 2f
    fun y(x: Float): Float {
        val d = abs(x - cx)
        return if (d <= shoulderHalf) {
            val t = (d / shoulderHalf).toDouble()                       // 0 center → 1 shoulder
            top + valleyDip * (0.5 + 0.5 * cos(Math.PI * t)).toFloat()
        } else {
            val t = ((d - shoulderHalf) / (cx - shoulderHalf)).toDouble() // 0 shoulder → 1 edge
            top + edgeDrop * (0.5 - 0.5 * cos(Math.PI * t)).toFloat()
        }
    }
    return Path().apply {
        moveTo(0f, y(0f))
        var x = 0f
        while (x <= w) { lineTo(x, y(x)); x += 2f }
        lineTo(w, y(w))
        lineTo(w, size.height)
        lineTo(0f, size.height)
        close()
    }
}

@Composable
private fun SideItem(tab: AppTab, icon: ImageVector, selected: AppTab, cs: androidx.compose.material3.ColorScheme, onClick: () -> Unit) {
    val active = tab == selected
    Box(
        modifier = Modifier.size(54.dp).clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            icon,
            contentDescription = stringResource(tab.titleRes),
            tint = cs.onPrimary.copy(alpha = if (active) 1f else 0.78f),
            modifier = Modifier.size(24.dp),
        )
    }
}

@Composable
private fun HomeCircle(cs: androidx.compose.material3.ColorScheme, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Column(
        modifier = modifier
            .size(92.dp)
            .clip(CircleShape)
            .background(cs.surface)
            .clickable(onClick = onClick),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Image(
            painter = painterResource(R.drawable.fatwabot_logo),
            contentDescription = null,
            modifier = Modifier.width(30.dp).height(40.dp),
        )
        Text(
            stringResource(AppTab.HOME.titleRes),
            style = MaterialTheme.typography.labelSmall,
            color = cs.primary,
            modifier = Modifier.padding(top = 1.dp),
        )
    }
}
