package com.fatwabot.feature.hadith

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.MenuBook
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.fatwabot.core.common.HadithDisplay
import com.fatwabot.core.common.expandingArabicHonorifics
import com.fatwabot.core.designsystem.ArabicContentCard
import com.fatwabot.core.designsystem.BrandEmptyState
import com.fatwabot.core.designsystem.ColorTokens
import com.fatwabot.core.designsystem.DarkTokens
import com.fatwabot.core.designsystem.LightTokens
import com.fatwabot.core.designsystem.brandScreenBackground
import com.fatwabot.feature.hadith.R

/**
 * Browsing the hadith corpus: a chip per collection, and every entry in the
 * selected one as a card. Mirror of iOS `HadithCollectionsScreen`.
 *
 * ## Why this replaced the reader
 * Hadith used to be two screens. This one listed the five collections as rows
 * with progress rings; tapping one opened `HadithReadingScreen`, which showed a
 * single entry at a time behind «السابق» / «التالي» buttons.
 *
 * That shape makes a collection unreadable as a collection. You cannot see what
 * is in it, cannot scan for the hadith you half-remember, and cannot get from
 * entry 3 to entry 40 without forty taps. Azkar had already solved the same
 * problem for the same kind of content one tab away, and the owner asked for
 * hadith to match it.
 *
 * ## What went with it
 * The prev/next reader is gone, and with it the per-entry translation block and
 * the «الفائدة» benefit-note card. The API still returns both.
 *
 * Progress did *not* go with it, because it feeds the streak. It changed meaning
 * instead: see [HadithViewModel.markRead] for why "read" now means "scrolled
 * into view".
 */
@Composable
fun HadithCollectionsScreen(
    viewModel: HadithViewModel = hiltViewModel(),
    locale: String = "ar",
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val tokens = if (isSystemInDarkTheme()) DarkTokens else LightTokens
    var selectedSlug by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(locale) { viewModel.loadCollections(locale) }

    // The backend serves only reviewed hadith, so a collection still under review
    // arrives with entryCount == 0. The old screen showed those as dimmed,
    // non-tappable rows; as a chip there is no equivalent — a chip that cannot be
    // selected reads as a broken control — so they are left out of the strip and
    // surfaced in the empty state instead.
    val readable = state.collections.filter { it.entryCount > 0 }

    // Resolved rather than read straight from state: a content resync can drop the
    // selected collection, which would leave every chip unhighlighted over an
    // empty list.
    val activeSlug = when {
        readable.any { it.slug == selectedSlug } -> selectedSlug
        else -> readable.firstOrNull()?.slug
    }

    LaunchedEffect(activeSlug, locale) {
        activeSlug?.let { viewModel.openCollection(it, locale) }
    }

    // `currentDetail` lags `activeSlug` by one load. Without this guard the
    // previous collection's entries render under the newly selected chip, which
    // looks like the wrong content rather than a pending one.
    val entries = state.currentDetail
        ?.takeIf { it.slug == activeSlug }
        ?.entries
        .orEmpty()

    Column(modifier = Modifier.fillMaxSize().brandScreenBackground(tokens)) {
        CollectionChips(
            collections = readable.map {
                ChipModel(it.slug, it.name, state.isCompleted(it.slug, it.entryCount))
            },
            activeSlug = activeSlug,
            tokens = tokens,
            onSelect = { selectedSlug = it },
        )

        when {
            readable.isEmpty() && !state.hasLoadedCollections -> Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center,
            ) { CircularProgressIndicator(color = tokens.primary) }

            // Covers both "nothing came down" and "everything that came down is
            // still under review" — from here they are the same thing.
            readable.isEmpty() -> BrandEmptyState(
                icon = Icons.AutoMirrored.Filled.MenuBook,
                message = stringResource(
                    if (state.collections.isEmpty()) {
                        R.string.hadith_empty
                    } else {
                        R.string.hadith_under_review
                    },
                ),
                tokens = tokens,
            )

            entries.isEmpty() -> Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center,
            ) { CircularProgressIndicator(color = tokens.primary) }

            else -> LazyColumn(
                verticalArrangement = Arrangement.spacedBy(12.dp),
                modifier = Modifier.fillMaxSize().padding(horizontal = 20.dp),
            ) {
                items(entries, key = { it.id }) { entry ->
                    LaunchedEffect(entry.id) { viewModel.markRead(entry.number) }
                    ArabicContentCard(
                        // The stored matn still ends with its own takhrij —
                        // migration 0029 copied that clause into `grading` rather
                        // than moving it — so without this the attribution shows
                        // twice, once as the label and again trailing the text.
                        // Android rendered it raw until now and did show it twice.
                        arabic = HadithDisplay.matnWithoutTakhrij(entry.arabicText, entry.grading),
                        tokens = tokens,
                        label = entry.grading.expandingArabicHonorifics,
                        badgeText = "${entry.number}",
                    )
                }
                item { Spacer(Modifier.height(24.dp)) }
            }
        }
    }
}

private data class ChipModel(val slug: String, val name: String, val completed: Boolean)

@Composable
private fun CollectionChips(
    collections: List<ChipModel>,
    activeSlug: String?,
    tokens: ColorTokens,
    onSelect: (String) -> Unit,
) {
    LazyRow(
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        contentPadding = PaddingValues(horizontal = 20.dp),
        modifier = Modifier.fillMaxWidth().padding(top = 4.dp, bottom = 14.dp),
    ) {
        items(collections, key = { it.slug }) { chip ->
            val isSelected = chip.slug == activeSlug
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(5.dp),
                modifier = Modifier
                    .clip(CircleShape)
                    .background(if (isSelected) tokens.primary else tokens.surfaceElevated)
                    .clickable { onSelect(chip.slug) }
                    .padding(horizontal = 16.dp, vertical = 9.dp),
            ) {
                // The progress ring from the old rows does not survive at chip
                // size, but "finished" is the part worth keeping.
                if (chip.completed) {
                    Icon(
                        Icons.Filled.Check,
                        contentDescription = stringResource(R.string.hadith_completed),
                        tint = if (isSelected) tokens.onPrimary else tokens.accent,
                        modifier = Modifier.size(14.dp),
                    )
                }
                Text(
                    text = chip.name,
                    color = if (isSelected) tokens.onPrimary else tokens.onSurface,
                    fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
                    style = MaterialTheme.typography.bodyMedium,
                )
            }
        }
    }
}
