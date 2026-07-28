package com.fatwabot.app.navigation

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.ui.res.painterResource
import com.fatwabot.app.R
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
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
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalContext
import com.fatwabot.app.notifications.ContentReminderViewModel
import com.fatwabot.app.notifications.WirdReminderViewModel
import com.fatwabot.core.common.AnalyticsEvents
import com.fatwabot.core.common.AnalyticsTracking
import com.fatwabot.core.common.DeepLink
import dagger.hilt.EntryPoint
import dagger.hilt.InstallIn
import dagger.hilt.android.EntryPointAccessors
import dagger.hilt.components.SingletonComponent
import com.fatwabot.feature.prayer.CityPicker
import com.fatwabot.feature.prayer.PrayerViewModel
import com.fatwabot.feature.prayer.formatTime
import com.fatwabot.feature.prayer.titleRes

@EntryPoint
@InstallIn(SingletonComponent::class)
private interface AnalyticsEntryPoint {
    fun analytics(): AnalyticsTracking
}

/**
 * M1 shell: 4 tabs with Home (server-layout sections) and Worship→Prayer live;
 * feature nav-graphs replace inline composition as features multiply (ADR-0005).
 */
@Composable
fun RootScaffold(deepLink: DeepLink? = null, onDeepLinkHandled: () -> Unit = {}) {
    var selected by rememberSaveable { mutableStateOf(AppTab.HOME) }
    var worshipDestination by rememberSaveable { mutableStateOf<WorshipDestination?>(null) }
    val prayerViewModel: PrayerViewModel = hiltViewModel()

    val context = LocalContext.current
    val analytics = remember {
        EntryPointAccessors
            .fromApplication(context.applicationContext, AnalyticsEntryPoint::class.java)
            .analytics()
    }
    // One place that reports "where is the user", rather than an onAppear in
    // every screen — those drift as screens are added and quietly stop firing.
    LaunchedEffect(selected, worshipDestination) {
        analytics.screenView(screenKey(selected, worshipDestination))
    }

    // Route a widget tap to the screen it promised, then clear it so the same
    // link isn't re-applied on every recomposition (or after the user navigates
    // away manually).
    LaunchedEffect(deepLink) {
        val link = deepLink ?: return@LaunchedEffect
        if (link == DeepLink.HOME) {
            selected = AppTab.HOME
            worshipDestination = null
        } else {
            selected = AppTab.WORSHIP
            worshipDestination = link.worshipDestination()
        }
        onDeepLinkHandled()
    }

    val contentReminderViewModel: ContentReminderViewModel = hiltViewModel()
    val wirdReminderViewModel: WirdReminderViewModel = hiltViewModel()
    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions(),
    ) {
        prayerViewModel.start()
        // After the prayer schedule, so the two never race for the shared
        // notification budget. Safe on every launch: the plan is seeded by the
        // day, so re-registering lands on the same alarms at the same times.
        contentReminderViewModel.rescheduleFromStore()
        // Last of the three, on the slice the other two left free. Also how a
        // wird created or archived since the last launch gains or loses its
        // reminder.
        wirdReminderViewModel.rescheduleFromStore()
    }

    LaunchedEffect(Unit) {
        val permissions = buildList {
            add(android.Manifest.permission.ACCESS_COARSE_LOCATION)
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
                add(android.Manifest.permission.POST_NOTIFICATIONS)
            }
        }
        permissionLauncher.launch(permissions.toTypedArray())
    }

    // The bar is a *tab-root* control: on a pushed screen you navigate with Back,
    // not by switching tabs, so 108dp of maroon band would only crowd content that
    // wants the room (the Tasbeeh tap target, the Qibla compass, a hadith being
    // read). Mirrors iOS `isShowingDetail`. Scaffold reports zero bottom padding
    // when the slot is empty, so hiding it also releases the reserved space.
    val isShowingDetail = selected == AppTab.WORSHIP && worshipDestination != null
    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        bottomBar = {
            AnimatedVisibility(
                visible = !isShowingDetail,
                enter = slideInVertically { it },
                exit = slideOutVertically { it },
            ) {
                FatwaBottomBar(selected = selected, onSelect = { selected = it })
            }
        },
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

/** Stable, non-PII screen key for analytics. A pushed worship destination wins
 * over the tab, since that's the screen actually on top. */
private fun screenKey(tab: AppTab, destination: WorshipDestination?): String = when {
    tab == AppTab.WORSHIP && destination != null -> when (destination) {
        WorshipDestination.PRAYER -> AnalyticsEvents.SCREEN_PRAYER
        WorshipDestination.QIBLA -> AnalyticsEvents.SCREEN_QIBLA
        WorshipDestination.TASBEEH -> AnalyticsEvents.SCREEN_TASBEEH
        WorshipDestination.AZKAR -> AnalyticsEvents.SCREEN_AZKAR
        WorshipDestination.DUA -> AnalyticsEvents.SCREEN_DUA
        WorshipDestination.AWRAD -> AnalyticsEvents.SCREEN_AWRAD
        WorshipDestination.HADITH -> AnalyticsEvents.SCREEN_HADITH
        WorshipDestination.JOURNEY -> AnalyticsEvents.SCREEN_JOURNEY
    }
    tab == AppTab.WORSHIP -> AnalyticsEvents.SCREEN_WORSHIP
    tab == AppTab.SETTINGS -> AnalyticsEvents.SCREEN_SETTINGS
    else -> AnalyticsEvents.SCREEN_HOME
}

/** Maroon cradle nav (client mockup, design/homeDesign.jpeg): a full-bleed maroon
 * band with a scooped top edge cradling a raised cream Home button (mihrab logo +
 * "الرئيسية"). A "⋯" (Settings) sits left, a 2×2 grid (Worship) right — white on
 * maroon. Forced LTR so placement matches the mockup in both languages. */
@Composable
private fun FatwaBottomBar(selected: AppTab, onSelect: (AppTab) -> Unit) {
    val cs = MaterialTheme.colorScheme
    val isDark = isSystemInDarkTheme()
    val bottomInset = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    val barHeight = 108.dp
    val homeLift = 26.dp
    // Reserved space ABOVE the band. Scaffold insets content by this composable's
    // MEASURED height, but the Home circle is drawn on an offset — which doesn't
    // affect measurement — so without this the bar visually occupies ~134dp while
    // only 108 is reserved, and content scrolls under the circle. Fixing it here
    // covers every screen at once; padding each screen would mean remembering the
    // number forever. (+6 clears the circle's shadow.)
    val overhang = homeLift + 6.dp
    CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = overhang)
                .height(barHeight + bottomInset)
                .drawBehind {
                    val path = cradlePath(size, 54.dp.toPx(), 18.dp.toPx(), 22.dp.toPx())
                    drawPath(path, cs.primary)
                    // `primary` is lifted in the dark palette so it can serve as a
                    // foreground on the near-black surface. At the size of this band
                    // that lift reads as pink rather than as the brand maroon, so
                    // knock it back with an opaque dark wash — the band is a brand
                    // *surface*, and wants the deep tone the light theme uses.
                    if (isDark) drawPath(path, Color.Black.copy(alpha = 0.42f))
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
            HomeCircle(cs, isDark, Modifier.align(Alignment.TopCenter).offset(y = -homeLift)) { onSelect(AppTab.HOME) }
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
private fun HomeCircle(
    cs: androidx.compose.material3.ColorScheme,
    isDark: Boolean,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    Column(
        modifier = modifier
            .size(92.dp)
            .clip(CircleShape)
            // In dark, `surface` is near-black — the same value as the page behind
            // the band, so the disc read as a hole punched through it rather than a
            // raised chip. `onSurface` is the warm cream that plays the role
            // `surface` plays in light: an opaque light disc lifted off the maroon.
            .background(if (isDark) cs.onSurface else cs.surface)
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
