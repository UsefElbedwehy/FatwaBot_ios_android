package com.fatwabot.app.navigation

import androidx.activity.compose.BackHandler
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
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.Paint
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.graphics.vector.ImageVector
import kotlin.math.abs
import kotlin.math.cos
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
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
import com.fatwabot.core.common.ContentFocus
import com.fatwabot.core.common.DeepLink
import com.fatwabot.core.designsystem.DarkTokens
import com.fatwabot.core.designsystem.LightTokens
import com.fatwabot.core.designsystem.brandScreenBackground
import dagger.hilt.EntryPoint
import dagger.hilt.InstallIn
import dagger.hilt.android.EntryPointAccessors
import dagger.hilt.components.SingletonComponent
import com.fatwabot.core.network.AuthenticatedApiClientProtocol
import com.fatwabot.feature.fatwasearch.FatwaSearchMode
import com.fatwabot.feature.fatwasearch.FatwaSearchScreen
import com.fatwabot.feature.fatwasearch.FatwaSearchViewModel
import com.fatwabot.feature.fatwasearch.titleRes
import com.fatwabot.feature.prayer.CityPicker
import com.fatwabot.feature.prayer.PrayerViewModel
import com.fatwabot.feature.prayer.formatTime
import com.fatwabot.feature.prayer.titleRes

@EntryPoint
@InstallIn(SingletonComponent::class)
private interface AnalyticsEntryPoint {
    fun analytics(): AnalyticsTracking
}

/** Resolves the authenticated client for [FatwaSearchViewModel], which is a
 * plain (non-Hilt) class — see its kdoc for why. Mirrors [AnalyticsEntryPoint]. */
@EntryPoint
@InstallIn(SingletonComponent::class)
private interface FatwaSearchEntryPoint {
    fun authenticatedClient(): AuthenticatedApiClientProtocol
}

/**
 * M1 shell: 4 tabs with Home (server-layout sections) and Worship→Prayer live;
 * feature nav-graphs replace inline composition as features multiply (ADR-0005).
 */
@Composable
fun RootScaffold(
    deepLink: DeepLink? = null,
    contentFocus: ContentFocus? = null,
    onDeepLinkHandled: () -> Unit = {},
) {
    var selected by rememberSaveable { mutableStateOf(AppTab.HOME) }
    var worshipDestination by rememberSaveable { mutableStateOf<WorshipDestination?>(null) }
    // Which specific azkar/hadith item to land on — set only when the link
    // that opened this path was a content-reminder notification. Plain
    // `remember` (not `rememberSaveable`), mirroring iOS `worshipContentFocus`:
    // it's re-derived from the intent on every cold start, not persisted.
    var worshipContentFocus by remember { mutableStateOf<ContentFocus?>(null) }
    // Home's own single-level "push" — mirrors worshipDestination above. Two
    // fields rather than one data class so `rememberSaveable` covers each
    // natively (enum + String), with no custom Saver to write.
    var homeSearchMode by rememberSaveable { mutableStateOf<FatwaSearchMode?>(null) }
    var homeSearchQuestion by rememberSaveable { mutableStateOf("") }
    val prayerViewModel: PrayerViewModel = hiltViewModel()

    val context = LocalContext.current
    val analytics = remember {
        EntryPointAccessors
            .fromApplication(context.applicationContext, AnalyticsEntryPoint::class.java)
            .analytics()
    }
    // One place that reports "where is the user", rather than an onAppear in
    // every screen — those drift as screens are added and quietly stop firing.
    LaunchedEffect(selected, worshipDestination, homeSearchMode) {
        analytics.screenView(screenKey(selected, worshipDestination, homeSearchMode))
    }

    // Route a widget tap to the screen it promised, then clear it so the same
    // link isn't re-applied on every recomposition (or after the user navigates
    // away manually).
    LaunchedEffect(deepLink) {
        val link = deepLink ?: return@LaunchedEffect
        if (link == DeepLink.HOME) {
            selected = AppTab.HOME
            worshipDestination = null
            homeSearchMode = null
        } else {
            selected = AppTab.WORSHIP
            worshipDestination = link.worshipDestination()
            worshipContentFocus = contentFocus
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
    val isShowingDetail = (selected == AppTab.WORSHIP && worshipDestination != null) ||
        (selected == AppTab.HOME && homeSearchMode != null)

    // System back pops the pushed screen instead of leaving the app. Without
    // this there was no handler at all for a pushed worship destination or the
    // Home search flow, so Android fell through to finishing the activity —
    // pressing back on Prayer or Qibla quit FatwaBot outright. A nested
    // BackHandler (e.g. RemembranceScreen's session) registers later and takes
    // priority, so this only fires once the inner levels are unwound.
    BackHandler(enabled = isShowingDetail) {
        if (selected == AppTab.HOME) homeSearchMode = null else worshipDestination = null
    }
    // The Scaffold paints the flat app background and each screen paints its
    // own `brandScreenBackground` inside the content slot — as it always did.
    //
    // Do NOT hoist that gradient to a root Box: it is a *vertical* gradient
    // (surface → primaryContainer@35%), so spanning it over the whole window
    // instead of the content area re-maps which colour lands at which screen
    // position. In dark mode that turned the lower screen maroon-tinted where
    // it had been near-black. The band above the bottom bar needs a fix that
    // doesn't touch screen backgrounds.
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
                AppTab.HOME -> HomeTab(
                    mode = homeSearchMode,
                    initialQuestion = homeSearchQuestion,
                    onOpen = { mode -> homeSearchMode = mode; homeSearchQuestion = "" },
                    onBack = { homeSearchMode = null },
                )
                AppTab.WORSHIP -> WorshipTab(
                    prayerViewModel = prayerViewModel,
                    destination = worshipDestination,
                    onDestinationChange = { worshipDestination = it },
                    contentFocus = worshipContentFocus,
                )
                AppTab.SETTINGS -> SettingsScreen(
                    prayerViewModel = prayerViewModel,
                    contact = rememberContactLinks(),
                )
            }
        }
    }
}

/** Home tab: the search-first landing screen, with a single-level "push" to
 * the AI-search flow for the tapped mode — mirrors [WorshipTab]'s
 * null-destination-means-menu pattern. [FatwaSearchViewModel] is a plain
 * class (see its kdoc), so it's `remember`'d per (mode, initialQuestion)
 * rather than obtained via `hiltViewModel()`. */
@Composable
private fun HomeTab(
    mode: FatwaSearchMode?,
    initialQuestion: String,
    onOpen: (FatwaSearchMode) -> Unit,
    onBack: () -> Unit,
) {
    if (mode == null) {
        SearchHome(onOpen = onOpen)
        return
    }
    val context = LocalContext.current
    val client = remember {
        EntryPointAccessors
            .fromApplication(context.applicationContext, FatwaSearchEntryPoint::class.java)
            .authenticatedClient()
    }
    val viewModel = remember(mode, initialQuestion) { FatwaSearchViewModel(client, mode, initialQuestion) }
    WorshipDetailScaffold(title = stringResource(mode.titleRes()), onBack = onBack) {
        FatwaSearchScreen(viewModel)
    }
}

/** Stable, non-PII screen key for analytics. A pushed worship/home destination
 * wins over the tab, since that's the screen actually on top. */
private fun screenKey(tab: AppTab, destination: WorshipDestination?, searchMode: FatwaSearchMode?): String = when {
    tab == AppTab.HOME && searchMode != null -> AnalyticsEvents.SCREEN_FATWA_SEARCH
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
                    // Soft upward shadow so the band reads as floating over the
                    // page rather than pasted onto it (iOS gets this from
                    // `.shadow(color: primary.opacity(0.28), radius: 16, y: -4)`).
                    // Compose's drawPath can't blur, so drop to the framework
                    // paint's shadow layer.
                    drawIntoCanvas { canvas ->
                        val paint = Paint()
                        paint.asFrameworkPaint().apply {
                            color = android.graphics.Color.TRANSPARENT
                            setShadowLayer(
                                16.dp.toPx(),
                                0f,
                                -4.dp.toPx(),
                                cs.primary.copy(alpha = 0.28f).toArgb(),
                            )
                        }
                        canvas.drawPath(path, paint)
                    }
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
                    .padding(horizontal = 44.dp),
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
        // 60dp to match iOS's tap frame, and clipped to a circle so the ripple
        // is a disc rather than a rectangle stamped onto the maroon band (iOS
        // uses `.buttonStyle(.plain)` — no press chrome at all).
        modifier = Modifier.size(60.dp).clip(CircleShape).clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            icon,
            contentDescription = stringResource(tab.titleRes),
            tint = cs.onPrimary.copy(alpha = if (active) 1f else 0.78f),
            // 28dp, not 24: Material pads its glyphs inside the 24dp box, so at
            // 24 they read noticeably lighter than iOS's semibold SF Symbols.
            modifier = Modifier.size(28.dp),
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
            // Before the clip, so the shadow falls outside the disc rather than
            // being clipped away — matches iOS's `.shadow(radius: 9, y: 3)`.
            .shadow(9.dp, CircleShape)
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
            painter = painterResource(com.fatwabot.core.designsystem.R.drawable.fatwabot_logo),
            contentDescription = null,
            modifier = Modifier.width(30.dp).height(40.dp),
            // Tinted like iOS's FatwaMark — the raw raster's baked-in colour is
            // not a brand token and reads poorly inside the cream disc.
            colorFilter = ColorFilter.tint(cs.primary),
        )
        Text(
            stringResource(AppTab.HOME.titleRes),
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.SemiBold,
            color = cs.primary,
            modifier = Modifier.padding(top = 1.dp),
        )
    }
}
