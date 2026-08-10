package com.fatwabot.feature.dua

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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Clear
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.fatwabot.core.content.Dua
import com.fatwabot.core.designsystem.ArabicContentCard
import com.fatwabot.core.designsystem.BrandEmptyState
import com.fatwabot.core.designsystem.ColorTokens
import com.fatwabot.core.designsystem.DarkTokens
import com.fatwabot.core.designsystem.LightTokens
import com.fatwabot.core.designsystem.brandScreenBackground
import com.fatwabot.feature.dua.R

/**
 * Browsing the du'a corpus: category chips, search, and every dua in the
 * selected category as a card carrying the dua itself. Mirror of iOS
 * `DuaLibraryScreen`.
 *
 * ## Why this replaced the previous library
 * The old screen was a directory, not a reader. Categories were stacked sections
 * of row cards showing a *title* and a source line; reading the actual dua meant
 * tapping through to a detail page, which then presented it as four stacked
 * blocks — an Arabic centrepiece, a transliteration card, a translation card and
 * a source row.
 *
 * So the same dua looked like one thing here and a different thing there, and
 * neither matched how Azkar presented an identical kind of passage two tabs
 * away. The owner's direction was to show the passage and drop the apparatus,
 * and to make Du'a behave like Azkar. Both are the same fix.
 *
 * ## What went with it
 * `DuaReadingScreen` is gone, and with it the transliteration and translation
 * blocks and the takhrij source line. The data still comes down from the API.
 *
 * The favourite toggle did *not* go with it — it moved onto the card rather than
 * disappearing as a side effect of removing the page it lived on.
 */
@Composable
fun DuaLibraryScreen(
    viewModel: DuaViewModel = hiltViewModel(),
    locale: String = "ar",
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val tokens = if (isSystemInDarkTheme()) DarkTokens else LightTokens
    var selectedCategoryId by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(locale) { viewModel.loadCategories(locale) }

    val showsFavoritesChip = state.favoriteDuas.isNotEmpty()

    // Resolved rather than read straight from state: unfavouriting the last dua
    // removes the favourites chip while it is selected, and a content resync can
    // drop a category. Either would otherwise leave the list empty with every
    // chip unhighlighted.
    val activeChipId = when {
        selectedCategoryId == FAVORITES_CHIP_ID ->
            if (showsFavoritesChip) FAVORITES_CHIP_ID else state.categories.firstOrNull()?.id
        state.categories.any { it.id == selectedCategoryId } -> selectedCategoryId
        else -> state.categories.firstOrNull()?.id
    }

    // Search wins over the chip selection: a query is a deliberate act, and
    // filtering it to one category would hide matches the user can see exist.
    val results = state.searchResults
    val visible: List<Dua> = when {
        results != null -> results
        activeChipId == FAVORITES_CHIP_ID -> state.favoriteDuas
        else -> state.categories.firstOrNull { it.id == activeChipId }?.duas.orEmpty()
    }

    Column(modifier = Modifier.fillMaxSize().brandScreenBackground(tokens)) {
        SearchField(state.searchQuery, tokens, viewModel::updateSearchQuery)

        CategoryChips(
            favoritesLabel = stringResource(R.string.dua_favorites).takeIf { showsFavoritesChip },
            categories = state.categories.map { it.id to it.name },
            activeId = activeChipId,
            tokens = tokens,
            onSelect = {
                selectedCategoryId = it
                // A query from the previous chip almost never applies to the
                // next one, and leaving it set shows an empty list that reads as
                // though the category itself is empty.
                viewModel.updateSearchQuery("")
            },
        )

        when {
            state.categories.isEmpty() && !state.hasLoadedCategories -> Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center,
            ) { CircularProgressIndicator(color = tokens.primary) }

            state.categories.isEmpty() -> BrandEmptyState(
                icon = Icons.Filled.AutoAwesome,
                message = stringResource(R.string.dua_empty),
                tokens = tokens,
            )

            // Distinguishing these matters: "no matches" and "this category is
            // empty" look identical otherwise, and the first is the user's doing
            // while the second is ours.
            visible.isEmpty() -> BrandEmptyState(
                icon = Icons.Filled.Search,
                message = stringResource(
                    if (results == null) R.string.dua_empty else R.string.dua_no_results,
                ),
                tokens = tokens,
            )

            else -> LazyColumn(
                verticalArrangement = Arrangement.spacedBy(12.dp),
                modifier = Modifier.fillMaxSize().padding(horizontal = 20.dp),
            ) {
                items(visible, key = { it.id }) { dua ->
                    ArabicContentCard(
                        arabic = dua.arabicText,
                        tokens = tokens,
                        label = dua.displayTitle,
                        accessory = {
                            FavoriteChip(
                                isFavorite = state.isFavorite(dua.id),
                                tokens = tokens,
                                onClick = { viewModel.toggleFavorite(dua.id) },
                            )
                        },
                    )
                }
                item { Spacer(Modifier.height(24.dp)) }
            }
        }
    }
}

/**
 * Sentinel id for the favourites chip. Not a real category, and cannot collide
 * with one: server category ids are UUIDs.
 */
private const val FAVORITES_CHIP_ID = "__favorites__"

@Composable
private fun SearchField(query: String, tokens: ColorTokens, onChange: (String) -> Unit) {
    TextField(
        value = query,
        onValueChange = onChange,
        singleLine = true,
        placeholder = { Text(stringResource(R.string.dua_search_hint)) },
        leadingIcon = { Icon(Icons.Filled.Search, contentDescription = null) },
        trailingIcon = {
            if (query.isNotEmpty()) {
                IconButton(onClick = { onChange("") }) {
                    Icon(Icons.Filled.Clear, contentDescription = null)
                }
            }
        },
        shape = RoundedCornerShape(14.dp),
        colors = TextFieldDefaults.colors(
            focusedContainerColor = tokens.surfaceElevated,
            unfocusedContainerColor = tokens.surfaceElevated,
            focusedIndicatorColor = Color.Transparent,
            unfocusedIndicatorColor = Color.Transparent,
            focusedTextColor = tokens.onSurface,
            unfocusedTextColor = tokens.onSurface,
        ),
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp)
            .padding(bottom = 12.dp),
    )
}

@Composable
private fun CategoryChips(
    favoritesLabel: String?,
    categories: List<Pair<String, String>>,
    activeId: String?,
    tokens: ColorTokens,
    onSelect: (String) -> Unit,
) {
    val chips = buildList {
        favoritesLabel?.let { add(FAVORITES_CHIP_ID to it) }
        addAll(categories)
    }
    LazyRow(
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        contentPadding = PaddingValues(horizontal = 20.dp),
        modifier = Modifier.fillMaxWidth().padding(bottom = 14.dp),
    ) {
        items(chips, key = { it.first }) { (id, title) ->
            val isSelected = id == activeId
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(5.dp),
                modifier = Modifier
                    .clip(CircleShape)
                    .background(if (isSelected) tokens.primary else tokens.surfaceElevated)
                    .clickable { onSelect(id) }
                    .padding(horizontal = 16.dp, vertical = 9.dp),
            ) {
                if (id == FAVORITES_CHIP_ID) {
                    Icon(
                        Icons.Filled.Favorite,
                        contentDescription = null,
                        tint = if (isSelected) tokens.onPrimary else tokens.onSurface,
                        modifier = Modifier.size(14.dp),
                    )
                }
                Text(
                    text = title,
                    color = if (isSelected) tokens.onPrimary else tokens.onSurface,
                    fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
                    style = MaterialTheme.typography.bodyMedium,
                )
            }
        }
    }
}

@Composable
private fun FavoriteChip(isFavorite: Boolean, tokens: ColorTokens, onClick: () -> Unit) {
    val tint = if (isFavorite) tokens.accent else tokens.primary
    Box(
        modifier = Modifier
            .clip(CircleShape)
            .background(tint.copy(alpha = 0.10f))
            .clickable(onClick = onClick)
            .padding(horizontal = 11.dp, vertical = 7.dp),
    ) {
        Icon(
            imageVector = if (isFavorite) Icons.Filled.Favorite else Icons.Filled.FavoriteBorder,
            contentDescription = stringResource(
                if (isFavorite) R.string.dua_unfavorite else R.string.dua_favorite,
            ),
            tint = tint,
            modifier = Modifier.size(14.dp),
        )
    }
}
