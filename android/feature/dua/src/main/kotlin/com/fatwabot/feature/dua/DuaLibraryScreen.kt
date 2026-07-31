package com.fatwabot.feature.dua

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Search
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
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.fatwabot.core.content.Dua
import com.fatwabot.core.content.DuaCategory
import com.fatwabot.core.designsystem.BrandCard
import com.fatwabot.core.designsystem.BrandEmptyState
import com.fatwabot.core.designsystem.BrandSectionHeader
import com.fatwabot.core.designsystem.ColorTokens
import com.fatwabot.core.designsystem.DarkTokens
import com.fatwabot.core.designsystem.LightTokens
import com.fatwabot.core.designsystem.brandScreenBackground
import com.fatwabot.feature.dua.R

/** Library browse/search home (docs/features/dua.md screen 1) — mirror of
 * iOS DuaLibraryScreen. */
@Composable
fun DuaLibraryScreen(
    onDuaSelected: (Dua) -> Unit,
    viewModel: DuaViewModel = hiltViewModel(),
    locale: String = "ar",
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val tokens = if (isSystemInDarkTheme()) DarkTokens else LightTokens

    LaunchedEffect(locale) { viewModel.loadCategories(locale) }

    Box(modifier = Modifier.fillMaxSize().brandScreenBackground(tokens)) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(22.dp),
        ) {
            SearchField(
                query = state.searchQuery,
                onQueryChange = viewModel::updateSearchQuery,
                tokens = tokens,
            )

            val results = state.searchResults
            if (results != null) {
                if (results.isEmpty()) {
                    BrandEmptyState(
                        icon = Icons.Filled.Search,
                        message = stringResource(R.string.dua_no_results),
                        tokens = tokens,
                    )
                } else {
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        BrandSectionHeader(stringResource(R.string.dua_search_results), icon = Icons.Filled.Search, tokens = tokens)
                        results.forEach { dua ->
                            DuaRowCard(
                                dua = dua,
                                isFavorite = state.isFavorite(dua.id),
                                tokens = tokens,
                                onClick = { onDuaSelected(dua) },
                            )
                        }
                    }
                }
            } else if (state.categories.isEmpty() && state.favoriteDuas.isEmpty()) {
                if (!state.hasLoadedCategories) {
                    Text(
                        stringResource(R.string.dua_loading),
                        color = tokens.onSurfaceSecondary,
                    )
                } else {
                    BrandEmptyState(
                        icon = Icons.Filled.AutoAwesome,
                        message = stringResource(R.string.dua_empty),
                        tokens = tokens,
                    )
                }
            } else {
                if (state.favoriteDuas.isNotEmpty()) {
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        BrandSectionHeader(stringResource(R.string.dua_favorites), icon = Icons.Filled.Favorite, tokens = tokens)
                        state.favoriteDuas.forEach { dua ->
                            DuaRowCard(
                                dua = dua,
                                isFavorite = true,
                                tokens = tokens,
                                onClick = { onDuaSelected(dua) },
                            )
                        }
                    }
                }
                state.categories.forEach { category: DuaCategory ->
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        BrandSectionHeader(category.name, tokens = tokens)
                        category.duas.forEach { dua ->
                            DuaRowCard(
                                dua = dua,
                                isFavorite = state.isFavorite(dua.id),
                                tokens = tokens,
                                onClick = { onDuaSelected(dua) },
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun SearchField(
    query: String,
    onQueryChange: (String) -> Unit,
    tokens: ColorTokens,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(tokens.surfaceElevated)
            .border(1.dp, tokens.outline.copy(alpha = 0.6f), RoundedCornerShape(16.dp))
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Icon(
            Icons.Filled.Search,
            contentDescription = null,
            tint = tokens.primary,
            modifier = Modifier.size(20.dp),
        )
        Box(modifier = Modifier.weight(1f)) {
            if (query.isEmpty()) {
                Text(
                    stringResource(R.string.dua_search_hint),
                    style = MaterialTheme.typography.bodyLarge,
                    color = tokens.onSurfaceSecondary,
                )
            }
            BasicTextField(
                value = query,
                onValueChange = onQueryChange,
                singleLine = true,
                textStyle = MaterialTheme.typography.bodyLarge.copy(color = tokens.onSurface),
                cursorBrush = androidx.compose.ui.graphics.SolidColor(tokens.primary),
                modifier = Modifier.fillMaxWidth(),
            )
        }
    }
}

@Composable
private fun DuaRowCard(
    dua: Dua,
    isFavorite: Boolean,
    tokens: ColorTokens,
    onClick: () -> Unit,
) {
    BrandCard(tokens = tokens) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clickable(onClick = onClick)
                .semantics(mergeDescendants = true) {},
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .clip(CircleShape)
                    .background(tokens.primaryContainer),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    if (isFavorite) Icons.Filled.Favorite else Icons.Filled.AutoAwesome,
                    contentDescription = null,
                    tint = if (isFavorite) tokens.accent else tokens.primary,
                    modifier = Modifier.size(20.dp),
                )
            }
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    dua.displayTitle,
                    style = MaterialTheme.typography.bodyLarge,
                    fontWeight = FontWeight.SemiBold,
                    color = tokens.onSurface,
                    textAlign = TextAlign.End,
                    modifier = Modifier.fillMaxWidth(),
                )
                if (dua.source.isNotEmpty()) {
                    Text(
                        dua.source,
                        style = MaterialTheme.typography.labelSmall,
                        color = tokens.onSurfaceSecondary,
                        textAlign = TextAlign.End,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            }
            Icon(
                Icons.AutoMirrored.Filled.KeyboardArrowRight,
                contentDescription = null,
                tint = tokens.onSurfaceSecondary.copy(alpha = 0.6f),
            )
        }
    }
}
