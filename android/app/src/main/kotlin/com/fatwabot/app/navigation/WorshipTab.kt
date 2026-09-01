package com.fatwabot.app.navigation

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.height
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
import androidx.compose.material.icons.automirrored.filled.LibraryBooks
import androidx.compose.material.icons.automirrored.filled.ShowChart
import androidx.compose.material.icons.filled.AccessTimeFilled
import androidx.compose.material.icons.filled.Apps
import androidx.compose.material.icons.filled.Book
import androidx.compose.material.icons.filled.Eco
import androidx.compose.material.icons.filled.Explore
import androidx.compose.material.icons.filled.Favorite
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.compose.ui.platform.LocalContext
import com.fatwabot.core.common.ContentFocus
import com.fatwabot.core.config.ConfigService
import dagger.hilt.EntryPoint
import dagger.hilt.InstallIn
import dagger.hilt.android.EntryPointAccessors
import dagger.hilt.components.SingletonComponent
import java.util.Locale
import com.fatwabot.feature.awrad.AwradBoardScreen
import com.fatwabot.feature.hadith.HadithCollectionsScreen
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

@EntryPoint
@InstallIn(SingletonComponent::class)
private interface ConfigServiceEntryPoint {
    fun configService(): ConfigService
}

/**
 * Advisory note for the Tasbeeh screen. Server-provided (ADR-0011) so it can be
 * edited without a release; falls back to the bundled placeholder when the server
 * hasn't supplied one, and to nothing if an operator blanks it deliberately.
 *
 * Resolved here in the app layer, not inside `:feature:tasbeeh`, so the feature
 * module keeps no dependency on config/network (ADR-0010).
 */
@Composable
private fun tasbeehNotice(): String? {
    val context = LocalContext.current
    val bundled = stringResource(R.string.tasbeeh_notice)
    return remember(bundled) {
        val configService = EntryPointAccessors.fromApplication(
            context.applicationContext, ConfigServiceEntryPoint::class.java,
        ).configService()
        val locale = Locale.getDefault().language
        when (val remote = configService.string("tasbeeh.notice", locale)) {
            null -> bundled
            else -> remote.ifEmpty { null }
        }
    }
}

// Declaration order is grid order (see WorshipMenu). AWRAD and TASBEEH swapped
// places at the owner's request — no change to what either does, just where
// they sit. AZKAR/DUA stay adjacent regardless: DUA is filtered out of the
// grid (see WorshipMenu) and only rides along for the segment relationship.
enum class WorshipDestination(@StringRes val titleRes: Int) {
    PRAYER(R.string.worship_prayer_times),
    QIBLA(R.string.worship_qibla),
    AWRAD(R.string.worship_wird_daily),
    AZKAR(R.string.worship_azkar),
    DUA(R.string.worship_dua),
    TASBEEH(R.string.worship_tasbeeh),
    HADITH(R.string.worship_hadith),
    JOURNEY(R.string.tab_journey),
}

@Composable
fun WorshipTab(
    prayerViewModel: PrayerViewModel,
    destination: WorshipDestination?,
    onDestinationChange: (WorshipDestination?) -> Unit,
    contentFocus: ContentFocus? = null,
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
        ) { TasbeehScreen(viewModel = hiltViewModel(), notice = tasbeehNotice()) }
        // One screen, two segments. The destination only decides which segment
        // opens, so the existing `fatwabot://azkar` / `fatwabot://dua` links and
        // the per-destination analytics keys keep working unchanged.
        WorshipDestination.AZKAR, WorshipDestination.DUA -> RemembranceScreen(
            initial = if (destination == WorshipDestination.DUA) {
                RemembranceSegment.DUA
            } else {
                RemembranceSegment.AZKAR
            },
            onExit = { onDestinationChange(null) },
            focus = contentFocus,
        )
        WorshipDestination.AWRAD -> WorshipDetailScaffold(
            title = stringResource(WorshipDestination.AWRAD.titleRes),
            onBack = { onDestinationChange(null) },
        ) { AwradBoardScreen(viewModel = hiltViewModel()) }
        // No pushed reader any more: the collections screen carries chips for the
        // five collections and lists every entry underneath, so there is nothing
        // left to open.
        WorshipDestination.HADITH -> WorshipDetailScaffold(
            title = stringResource(WorshipDestination.HADITH.titleRes),
            onBack = { onDestinationChange(null) },
        ) {
            HadithCollectionsScreen(
                focusEntryId = contentFocus?.contentId,
                focusCollectionSlug = contentFocus?.categorySlug,
            )
        }
        WorshipDestination.JOURNEY -> {
            BackHandler { onDestinationChange(null) }
            JourneyTab()
        }
    }
}

/** Grid label. AZKAR and AWRAD both differ from their own `titleRes`:
 *  - AZKAR's tile is the entry point for the merged Azkar + Du'a screen, so it
 *    announces both. `titleRes` stays the name of the Azkar library itself —
 *    that's what the segment label needs.
 *  - AWRAD's tile reads "Wird" ("ورد"); the pushed screen's title is the fuller
 *    "Daily Wird" ("الورد اليومي"). Two different jobs, two strings. */
@StringRes
private fun tileTitleRes(destination: WorshipDestination): Int = when (destination) {
    WorshipDestination.AZKAR -> R.string.worship_remembrance
    WorshipDestination.AWRAD -> R.string.worship_wird_tile
    else -> destination.titleRes
}

/** Chosen to match the iOS tile's SF Symbol as closely as Material allows —
 *  all solid/filled, since every iOS glyph here is a `.fill` variant. */
private fun iconFor(destination: WorshipDestination) = when (destination) {
    // Solid clock face, not the outlined AccessTime — iOS uses `clock.fill`.
    WorshipDestination.PRAYER -> Icons.Filled.AccessTimeFilled
    WorshipDestination.QIBLA -> Icons.Filled.Explore
    // Closed filled book (`book.closed.fill`), not an open outlined one.
    WorshipDestination.AZKAR -> Icons.Filled.Book
    WorshipDestination.DUA -> Icons.Filled.Favorite
    // A leaf (`leaf.fill`). `Spa` is a lotus/spa flower — a different plant
    // entirely and the wrong read for a daily wird.
    WorshipDestination.AWRAD -> Icons.Filled.Eco
    // Auto-mirrored: the stacked-books glyph has a spine side, and this is an
    // Arabic-first app where the non-mirrored variant faces the wrong way.
    WorshipDestination.HADITH -> Icons.AutoMirrored.Filled.LibraryBooks
    WorshipDestination.JOURNEY -> Icons.AutoMirrored.Filled.ShowChart
    // Was missing entirely, so Tasbeeh fell through to a single plain dot
    // where iOS shows a 3×3 grid (`circle.grid.3x3.fill`).
    WorshipDestination.TASBEEH -> Icons.Filled.Apps
}

@Composable
private fun WorshipMenu(hasLocation: Boolean, onSelect: (WorshipDestination) -> Unit) {
    // DUA is still a routable destination (deep links, analytics) — it just no
    // longer gets its own tile: AZKAR's tile now opens the merged Azkar + Du'a
    // screen, so a second tile would land on the same place.
    val visible = WorshipDestination.entries.filter {
        (it != WorshipDestination.QIBLA || hasLocation) && it != WorshipDestination.DUA
    }
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
        // No forced square: iOS sizes the tile from its content (plate + label),
        // so a two-line label grows the tile instead of squeezing inside it.
        modifier = Modifier.clickable(onClick = onClick),
    ) {
        Column(
            modifier = Modifier.fillMaxWidth().padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = androidx.compose.foundation.layout.Arrangement.Center,
        ) {
            Box(
                // Full-width 88dp plate, matching iOS — it was a 64dp square
                // floating in the middle of the tile.
                modifier = Modifier
                    .fillMaxWidth()
                    .height(88.dp)
                    .background(MaterialTheme.colorScheme.primaryContainer, RoundedCornerShape(20.dp)),
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
                stringResource(tileTitleRes(destination)),
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Medium,
                textAlign = TextAlign.Center,
                maxLines = 2,
            )
        }
    }
}

/** Shared back-bar chrome for every pushed worship screen. Not private: the merged
 * Azkar + Du'a screen lives in its own file and needs the same bar. */
@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
internal fun WorshipDetailScaffold(title: String, onBack: () -> Unit, content: @Composable () -> Unit) {
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
