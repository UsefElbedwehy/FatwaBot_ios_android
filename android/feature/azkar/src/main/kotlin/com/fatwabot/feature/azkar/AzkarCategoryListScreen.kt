package com.fatwabot.feature.azkar

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.MenuBook
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.fatwabot.core.content.AzkarCategory
import com.fatwabot.core.designsystem.BrandCard
import com.fatwabot.core.designsystem.BrandEmptyState
import com.fatwabot.core.designsystem.DarkTokens
import com.fatwabot.core.designsystem.LightTokens
import com.fatwabot.core.designsystem.brandScreenBackground
import com.fatwabot.feature.azkar.R

/** Category browser (docs/features/azkar.md screen 1) — mirror of iOS
 * AzkarCategoryListScreen. Loads from ContentKit (offline-first). */
@Composable
fun AzkarCategoryListScreen(
    onCategorySelected: (AzkarCategory) -> Unit,
    viewModel: AzkarViewModel = hiltViewModel(),
    locale: String = "ar",
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val tokens = if (isSystemInDarkTheme()) DarkTokens else LightTokens

    LaunchedEffect(locale) { viewModel.loadCategories(locale) }

    Box(modifier = Modifier.fillMaxSize().brandScreenBackground(tokens)) {
        if (state.categories.isEmpty()) {
            if (!state.hasLoadedCategories) {
                Column(
                    modifier = Modifier.align(Alignment.Center),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    CircularProgressIndicator(color = tokens.primary)
                    Text(stringResource(R.string.azkar_loading), color = tokens.onSurfaceSecondary)
                }
            } else {
                BrandEmptyState(
                    icon = Icons.Filled.MenuBook,
                    message = stringResource(R.string.azkar_empty_message),
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
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                // No section header here: this list is hosted by the merged
                // Azkar + Du'a screen, whose segmented control already reads
                // "الأذكار", so a header would just repeat the segment label.
                state.categories.forEach { category ->
                    CategoryRow(
                        category = category,
                        done = viewModel.isCompletedToday(category.id),
                        tokens = tokens,
                        onClick = { onCategorySelected(category) },
                    )
                }
            }
        }
    }
}

@Composable
private fun CategoryRow(
    category: AzkarCategory,
    done: Boolean,
    tokens: com.fatwabot.core.designsystem.ColorTokens,
    onClick: () -> Unit,
) {
    BrandCard(tokens = tokens) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clickable(onClick = onClick)
                .semantics(mergeDescendants = true) {},
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Box(
                modifier = Modifier
                    .size(46.dp)
                    .clip(CircleShape)
                    .background(
                        if (done) tokens.primary.copy(alpha = 0.14f)
                        else tokens.primaryContainer,
                    ),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    Icons.Filled.MenuBook,
                    contentDescription = null,
                    tint = tokens.primary,
                    modifier = Modifier.size(22.dp),
                )
            }
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    category.name,
                    style = MaterialTheme.typography.bodyLarge,
                    fontWeight = FontWeight.SemiBold,
                    color = tokens.onSurface,
                )
                Text(
                    "${category.items.count()}",
                    style = MaterialTheme.typography.labelMedium,
                    color = tokens.onSurfaceSecondary,
                )
            }
            Spacer(Modifier.width(4.dp))
            if (done) {
                Icon(
                    Icons.Filled.CheckCircle,
                    contentDescription = stringResource(R.string.azkar_done_today),
                    tint = tokens.primary,
                )
            } else {
                Icon(
                    Icons.AutoMirrored.Filled.KeyboardArrowRight,
                    contentDescription = null,
                    tint = tokens.onSurfaceSecondary.copy(alpha = 0.7f),
                )
            }
        }
    }
}
