package com.fatwabot.feature.hadith

import androidx.compose.foundation.clickable
import androidx.compose.material.icons.filled.HourglassEmpty
import androidx.compose.ui.draw.alpha
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.automirrored.filled.MenuBook
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.fatwabot.feature.hadith.R
import com.fatwabot.core.content.HadithCollectionSummary
import com.fatwabot.core.designsystem.BrandCard
import com.fatwabot.core.designsystem.BrandEmptyState
import com.fatwabot.core.designsystem.ColorTokens
import com.fatwabot.core.designsystem.DarkTokens
import com.fatwabot.core.designsystem.LightTokens
import com.fatwabot.core.designsystem.RingProgress
import com.fatwabot.core.designsystem.brandScreenBackground

/** Collections browser (docs/features/hadith-collections.md screen 1) —
 * mirror of iOS HadithCollectionsScreen. */
@Composable
fun HadithCollectionsScreen(
    onCollectionSelected: (HadithCollectionSummary) -> Unit,
    viewModel: HadithViewModel = hiltViewModel(),
    locale: String = "ar",
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val tokens = if (isSystemInDarkTheme()) DarkTokens else LightTokens

    LaunchedEffect(locale) { viewModel.loadCollections(locale) }

    Box(modifier = Modifier.fillMaxSize().brandScreenBackground(tokens)) {
        if (state.collections.isEmpty()) {
            if (!state.hasLoadedCollections) {
                CircularProgressIndicator(
                    color = tokens.primary,
                    modifier = Modifier.align(Alignment.Center),
                )
            } else {
                BrandEmptyState(
                    icon = Icons.AutoMirrored.Filled.MenuBook,
                    message = stringResource(R.string.hadith_empty),
                    modifier = Modifier.align(Alignment.Center),
                    tokens = tokens,
                )
            }
        } else {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(20.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                state.collections.forEach { collection ->
                    CollectionCard(
                        collection = collection,
                        readCount = state.readCount(collection.slug),
                        completed = state.isCompleted(collection.slug, collection.entryCount),
                        tokens = tokens,
                        onClick = { onCollectionSelected(collection) },
                    )
                }
            }
        }
    }
}

@Composable
private fun CollectionCard(
    collection: HadithCollectionSummary,
    readCount: Int,
    completed: Boolean,
    tokens: ColorTokens,
    onClick: () -> Unit,
) {
    val fraction = if (collection.entryCount > 0) readCount.toFloat() / collection.entryCount else 0f
    // A collection with nothing approved yet is shown but not clickable: the
    // backend only serves reviewed entries, so opening it lands on a blank
    // reader that looks like a failure rather than a policy.
    val underReview = collection.entryCount == 0
    BrandCard(
        tokens = tokens,
        modifier = if (underReview) Modifier.alpha(0.62f) else Modifier.clickable { onClick() },
    ) {
        Row(
            modifier = Modifier.fillMaxWidth().semantics(mergeDescendants = true) {},
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Box(contentAlignment = Alignment.Center, modifier = Modifier.size(44.dp)) {
                RingProgress(value = fraction, strokeWidth = 5.dp, modifier = Modifier.fillMaxSize())
                Icon(
                    when {
                        underReview -> Icons.Filled.HourglassEmpty
                        completed -> Icons.Filled.Check
                        else -> Icons.AutoMirrored.Filled.MenuBook
                    },
                    contentDescription = if (completed) stringResource(R.string.hadith_completed) else null,
                    tint = if (completed) tokens.accent else tokens.primary,
                    modifier = Modifier.size(20.dp),
                )
            }
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    collection.name,
                    style = MaterialTheme.typography.bodyLarge,
                    fontWeight = FontWeight.SemiBold,
                    color = tokens.onSurface,
                )
                Text(
                    if (underReview) {
                        stringResource(R.string.hadith_under_review)
                    } else {
                        stringResource(R.string.hadith_read_count, readCount, collection.entryCount)
                    },
                    style = MaterialTheme.typography.labelSmall,
                    color = tokens.onSurfaceSecondary,
                )
            }
            if (!underReview) {
                Icon(
                    Icons.AutoMirrored.Filled.KeyboardArrowRight,
                    contentDescription = null,
                    tint = tokens.onSurfaceSecondary.copy(alpha = 0.7f),
                    modifier = Modifier.size(20.dp),
                )
            }
        }
    }
}
