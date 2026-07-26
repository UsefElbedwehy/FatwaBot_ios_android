package com.fatwabot.app.navigation

import androidx.annotation.StringRes
import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.fatwabot.app.R
import com.fatwabot.core.content.AzkarCategory
import com.fatwabot.core.content.Dua
import com.fatwabot.core.designsystem.DarkTokens
import com.fatwabot.core.designsystem.LightTokens
import com.fatwabot.feature.azkar.AzkarCategoryListScreen
import com.fatwabot.feature.azkar.AzkarSessionScreen
import com.fatwabot.feature.dua.DuaLibraryScreen
import com.fatwabot.feature.dua.DuaReadingScreen

/** Which library the merged screen is showing. */
enum class RemembranceSegment(@StringRes val titleRes: Int) {
    AZKAR(R.string.worship_azkar),
    DUA(R.string.worship_dua),
}

/**
 * Azkar and Du'a merged into one screen behind a segmented control (client
 * request, 2026-07-26) — they were previously two Worship tiles leading to two
 * separate screens. Mirror of iOS `RemembranceScreen`.
 *
 * Neither feature is rewritten. Each library keeps its own view model (resolved
 * by `hiltViewModel()` inside the library composable, so it is activity-scoped
 * and survives a segment flip without reloading from scratch) and its own deeper
 * navigation — category → session, dua → reading. Only the *entry point* is
 * unified, which keeps the merge a navigation change and means both
 * `fatwabot://azkar` and `fatwabot://dua` still land on the right content: they
 * open this screen with a different segment preselected, and analytics still
 * reports `azkar`/`dua` distinctly (see `screenKey` in RootScaffold).
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RemembranceScreen(initial: RemembranceSegment, onExit: () -> Unit) {
    var segment by rememberSaveable { mutableStateOf(initial) }
    // A second deep link arriving while this screen is already on top reuses the
    // same composable, so `initial` has to be able to move the segment — without
    // this, `fatwabot://dua` tapped from Azkar would be silently ignored. Guarded
    // by the last value we honoured (and that too is saveable): a bare
    // `LaunchedEffect(initial)` also restarts on rotation and after process
    // restore, which would throw away the segment the user actually chose.
    var appliedInitial by rememberSaveable { mutableStateOf(initial) }
    LaunchedEffect(initial) {
        if (initial != appliedInitial) {
            segment = initial
            appliedInitial = initial
        }
    }

    // Each library's push target, held separately so flipping the segment and
    // coming back doesn't lose your place. (Not `rememberSaveable`: the content
    // models aren't Parcelable — same as before the merge.)
    var selectedCategory by remember { mutableStateOf<AzkarCategory?>(null) }
    var selectedDua by remember { mutableStateOf<Dua?>(null) }

    val tokens = if (isSystemInDarkTheme()) DarkTokens else LightTokens
    val cs = MaterialTheme.colorScheme

    // The pushed detail owns the title bar while it's up, exactly as it did when
    // Azkar and Du'a were separate destinations.
    val detailTitle = when (segment) {
        RemembranceSegment.AZKAR -> selectedCategory?.name
        RemembranceSegment.DUA -> selectedDua?.title
    }
    WorshipDetailScaffold(
        title = detailTitle ?: stringResource(R.string.worship_remembrance),
        onBack = {
            when {
                segment == RemembranceSegment.AZKAR && selectedCategory != null -> selectedCategory = null
                segment == RemembranceSegment.DUA && selectedDua != null -> selectedDua = null
                else -> onExit()
            }
        },
    ) {
        Column(modifier = Modifier.fillMaxSize().background(tokens.surface)) {
            // Hidden while a detail is open: the toggle switches *libraries*, and
            // offering that on top of a single zikr or dua being read would let you
            // swap the content out from under the title bar.
            if (detailTitle == null) {
                SingleChoiceSegmentedButtonRow(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 20.dp, vertical = 10.dp),
                ) {
                    RemembranceSegment.entries.forEachIndexed { index, option ->
                        SegmentedButton(
                            selected = segment == option,
                            onClick = { segment = option },
                            shape = SegmentedButtonDefaults.itemShape(
                                index = index,
                                count = RemembranceSegment.entries.size,
                            ),
                            // Brand maroon fill for the active half rather than
                            // Material's tinted "secondaryContainer", which isn't a
                            // token we ship and reads as a foreign accent here.
                            colors = SegmentedButtonDefaults.colors(
                                activeContainerColor = cs.primary,
                                activeContentColor = cs.onPrimary,
                                activeBorderColor = cs.primary,
                                inactiveContainerColor = cs.surface,
                                inactiveContentColor = cs.primary,
                                inactiveBorderColor = cs.primary,
                            ),
                            icon = {},   // the default checkmark shoves the label off-centre
                            label = { Text(stringResource(option.titleRes)) },
                        )
                    }
                }
            }

            // `weight(1f)`, not a bare child: every library screen is `fillMaxSize()`
            // internally (it used to be the scaffold's only child), so without a
            // weight it would claim the whole column height and push its own bottom
            // off-screen by the height of the toggle.
            Box(modifier = Modifier.weight(1f)) {
                // Switched, not layered: only the visible library is composed, so the
                // other one isn't loading content or holding list state.
                when (segment) {
                    RemembranceSegment.AZKAR -> {
                        val category = selectedCategory
                        if (category == null) {
                            AzkarCategoryListScreen(onCategorySelected = { selectedCategory = it })
                        } else {
                            AzkarSessionScreen(category = category)
                        }
                    }
                    RemembranceSegment.DUA -> {
                        val dua = selectedDua
                        if (dua == null) {
                            DuaLibraryScreen(onDuaSelected = { selectedDua = it })
                        } else {
                            DuaReadingScreen(dua = dua)
                        }
                    }
                }
            }
        }
    }
}
