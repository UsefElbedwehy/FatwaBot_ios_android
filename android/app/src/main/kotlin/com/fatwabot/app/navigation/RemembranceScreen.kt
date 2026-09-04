package com.fatwabot.app.navigation

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Clear
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material.icons.filled.MenuBook
import androidx.compose.material.icons.filled.PlayArrow
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
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.fatwabot.app.R
import com.fatwabot.core.common.ContentFocus
import com.fatwabot.core.content.AzkarCategory
import com.fatwabot.core.content.AzkarItem
import com.fatwabot.core.content.Dua
import com.fatwabot.core.content.DuaCategory
import com.fatwabot.core.designsystem.ArabicContentCard
import com.fatwabot.core.designsystem.BrandEmptyState
import com.fatwabot.core.designsystem.ColorTokens
import com.fatwabot.core.designsystem.DarkTokens
import com.fatwabot.core.designsystem.LightTokens
import com.fatwabot.core.designsystem.RepeatCountLabel
import com.fatwabot.core.designsystem.brandScreenBackground
import com.fatwabot.feature.azkar.AzkarSearch
import com.fatwabot.feature.azkar.AzkarSessionScreen
import com.fatwabot.feature.azkar.AzkarViewModel
import com.fatwabot.feature.dua.DuaViewModel
import java.util.Locale
import kotlinx.coroutines.delay
import com.fatwabot.feature.azkar.R as AzkarR
import com.fatwabot.feature.dua.R as DuaR

/** Which library the merged screen opens on — set by which deep link/tile got
 *  here (`fatwabot://azkar` vs `fatwabot://dua`). Both land on this one
 *  screen; this only picks the initially-selected chip. */
enum class RemembranceSegment { AZKAR, DUA }

private sealed class RemembranceSelection {
    data class Azkar(val id: String) : RemembranceSelection()
    data class Dua(val id: String) : RemembranceSelection()
    object Favorites : RemembranceSelection()
}

/**
 * Azkar and Du'a merged into one screen behind a single category strip
 * (client direction, 2026-08-15) — replacing the earlier Azkar/Du'a segmented
 * control (2026-07-26) with one continuous row of chips spanning both
 * corpora, so the screen reads as one table of contents rather than two tabs
 * the reader has to know to switch between. Mirror of iOS `RemembranceScreen`.
 *
 * The two libraries still keep their own view models and their own session/
 * favourites logic; only the chip strip, search field and card list are
 * unified here. A chip's *kind* (azkar category, dua category, or dua
 * favourites) decides which card style and per-item actions render below it.
 */
@Composable
fun RemembranceScreen(
    initial: RemembranceSegment,
    onExit: () -> Unit,
    azkarViewModel: AzkarViewModel = hiltViewModel(),
    duaViewModel: DuaViewModel = hiltViewModel(),
    locale: String = "ar",
    /** Which specific item to scroll to, from a content-reminder tap. Only
     *  azkar reminders exist today (there is no dua notification kind), so
     *  this only ever selects an azkar chip. */
    focus: ContentFocus? = null,
) {
    val azkarState by azkarViewModel.state.collectAsStateWithLifecycle()
    val duaState by duaViewModel.state.collectAsStateWithLifecycle()
    val tokens = if (isSystemInDarkTheme()) DarkTokens else LightTokens

    var selection by remember { mutableStateOf<RemembranceSelection?>(null) }
    var query by remember { mutableStateOf("") }
    // Azkar-only push, exactly as before the merge: starting a session pushes
    // full-screen and owns the title bar until it's dismissed. Du'a no longer
    // pushes a detail — its library shows each dua in full.
    var sessionCategory by remember { mutableStateOf<AzkarCategory?>(null) }
    var highlightedItemId by remember { mutableStateOf<String?>(null) }
    val azkarListState = rememberLazyListState()

    // The counting session is a level RootScaffold can't see, so it needs its
    // own handler. Registered inside this screen, it takes priority over the
    // root one — back closes the session first, then leaves the screen.
    BackHandler(enabled = sessionCategory != null) { sessionCategory = null }

    LaunchedEffect(locale) {
        azkarViewModel.loadCategories(locale)
        duaViewModel.loadCategories(locale)
        // Land on the category a reminder's item actually belongs to —
        // without this the item may not even be in `visibleAzkarItems` yet,
        // since that is filtered to whichever chip is selected.
        val focusCategoryId = focus?.categorySlug
        if (focusCategoryId != null) {
            selection = RemembranceSelection.Azkar(focusCategoryId)
        } else if (selection == null) {
            selection = if (initial == RemembranceSegment.DUA) {
                duaViewModel.state.value.categories.firstOrNull()?.let { RemembranceSelection.Dua(it.id) }
            } else {
                azkarViewModel.state.value.categories.firstOrNull()?.let { RemembranceSelection.Azkar(it.id) }
            }
        }
    }

    val showsFavoritesChip = duaState.favoriteDuas.isNotEmpty()

    // Resolves the stored selection to something guaranteed valid, falling
    // back the same way each original screen did when the stored id goes
    // stale: a content resync dropping a category, or unfavouriting the
    // last dua while favourites is what's selected.
    val resolvedSelection: RemembranceSelection? = run {
        val current = selection
        val stillValid = when (current) {
            is RemembranceSelection.Azkar -> azkarState.categories.any { it.id == current.id }
            is RemembranceSelection.Dua -> duaState.categories.any { it.id == current.id }
            RemembranceSelection.Favorites -> showsFavoritesChip
            null -> false
        }
        if (stillValid) {
            current
        } else {
            azkarState.categories.firstOrNull()?.let { RemembranceSelection.Azkar(it.id) }
                ?: duaState.categories.firstOrNull()?.let { RemembranceSelection.Dua(it.id) }
        }
    }

    val selectedAzkarCategory = (resolvedSelection as? RemembranceSelection.Azkar)?.let { sel ->
        azkarState.categories.firstOrNull { it.id == sel.id }
    }
    val selectedDuaCategory = (resolvedSelection as? RemembranceSelection.Dua)?.let { sel ->
        duaState.categories.firstOrNull { it.id == sel.id }
    }

    // Search covers title, matn and source for azkar and is scoped to the
    // active category, unlike dua search below.
    val visibleAzkarItems = AzkarSearch.filter(selectedAzkarCategory?.items.orEmpty(), query)

    // Dua search already spans every category once a query is entered
    // (`DuaViewModel.UiState.searchResults`) — kept as-is rather than
    // narrowed to the active chip.
    val duaSearchResults = duaState.searchResults
    val visibleDuas: List<Dua> = when {
        duaSearchResults != null -> duaSearchResults
        resolvedSelection is RemembranceSelection.Favorites -> duaState.favoriteDuas
        else -> selectedDuaCategory?.duas.orEmpty()
    }

    fun select(newSelection: RemembranceSelection) {
        selection = newSelection
        // A query from the previous chip almost never applies to the next
        // one, and leaving it set shows an empty list that reads as though
        // the category itself is empty.
        query = ""
        duaViewModel.updateSearchQuery("")
    }

    WorshipDetailScaffold(
        title = sessionCategory?.name ?: stringResource(R.string.worship_remembrance),
        onBack = {
            if (sessionCategory != null) sessionCategory = null else onExit()
        },
    ) {
        if (sessionCategory != null) {
            AzkarSessionScreen(category = sessionCategory!!, viewModel = azkarViewModel)
        } else {
            Column(modifier = Modifier.fillMaxSize().brandScreenBackground(tokens)) {
                SearchField(
                    query = query,
                    tokens = tokens,
                    onChange = {
                        query = it
                        duaViewModel.updateSearchQuery(it)
                    },
                )
                CategoryChips(
                    azkarCategories = azkarState.categories,
                    duaCategories = duaState.categories,
                    showsFavoritesChip = showsFavoritesChip,
                    resolvedSelection = resolvedSelection,
                    tokens = tokens,
                    onSelect = ::select,
                )

                if (azkarState.categories.isEmpty() && duaState.categories.isEmpty()) {
                    if (!azkarState.hasLoadedCategories || !duaState.hasLoadedCategories) {
                        LoadingBox(tokens)
                    } else {
                        BrandEmptyState(
                            icon = Icons.Filled.MenuBook,
                            message = stringResource(AzkarR.string.azkar_empty_message),
                            tokens = tokens,
                        )
                    }
                } else {
                    when (resolvedSelection) {
                        is RemembranceSelection.Azkar -> AzkarContentSection(
                            category = selectedAzkarCategory,
                            items = visibleAzkarItems,
                            isCompletedToday = selectedAzkarCategory?.let { azkarViewModel.isCompletedToday(it.id) } == true,
                            tokens = tokens,
                            locale = locale,
                            listState = azkarListState,
                            focusItemId = focus?.contentId,
                            highlightedItemId = highlightedItemId,
                            onHighlightChange = { highlightedItemId = it },
                            onStartSession = { sessionCategory = it },
                        )
                        is RemembranceSelection.Dua, RemembranceSelection.Favorites -> DuaContentSection(
                            duas = visibleDuas,
                            isSearching = duaSearchResults != null,
                            isFavorite = duaState::isFavorite,
                            onToggleFavorite = duaViewModel::toggleFavorite,
                            tokens = tokens,
                        )
                        null -> LoadingBox(tokens)
                    }
                }
            }
        }
    }
}

@Composable
private fun LoadingBox(tokens: ColorTokens) {
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        CircularProgressIndicator(color = tokens.primary)
    }
}

@Composable
private fun SearchField(query: String, tokens: ColorTokens, onChange: (String) -> Unit) {
    TextField(
        value = query,
        onValueChange = onChange,
        singleLine = true,
        placeholder = { Text(stringResource(AzkarR.string.azkar_search_placeholder)) },
        leadingIcon = { Icon(Icons.Filled.Search, contentDescription = null) },
        trailingIcon = {
            if (query.isNotEmpty()) {
                IconButton(onClick = { onChange("") }) {
                    Icon(
                        Icons.Filled.Clear,
                        contentDescription = stringResource(AzkarR.string.azkar_search_clear),
                    )
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
    azkarCategories: List<AzkarCategory>,
    duaCategories: List<DuaCategory>,
    showsFavoritesChip: Boolean,
    resolvedSelection: RemembranceSelection?,
    tokens: ColorTokens,
    onSelect: (RemembranceSelection) -> Unit,
) {
    LazyRow(
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        contentPadding = PaddingValues(horizontal = 20.dp),
        modifier = Modifier.fillMaxWidth().padding(bottom = 14.dp),
    ) {
        items(azkarCategories, key = { "azkar-${it.id}" }) { category ->
            val selection = RemembranceSelection.Azkar(category.id)
            Chip(
                title = category.name,
                icon = null,
                isSelected = resolvedSelection == selection,
                tokens = tokens,
                onClick = { onSelect(selection) },
            )
        }
        if (showsFavoritesChip) {
            item(key = "favorites") {
                Chip(
                    title = stringResource(DuaR.string.dua_favorites),
                    icon = Icons.Filled.Favorite,
                    isSelected = resolvedSelection == RemembranceSelection.Favorites,
                    tokens = tokens,
                    onClick = { onSelect(RemembranceSelection.Favorites) },
                )
            }
        }
        items(duaCategories, key = { "dua-${it.id}" }) { category ->
            val selection = RemembranceSelection.Dua(category.id)
            Chip(
                title = category.name,
                icon = null,
                isSelected = resolvedSelection == selection,
                tokens = tokens,
                onClick = { onSelect(selection) },
            )
        }
    }
}

@Composable
private fun Chip(
    title: String,
    icon: ImageVector?,
    isSelected: Boolean,
    tokens: ColorTokens,
    onClick: () -> Unit,
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(5.dp),
        modifier = Modifier
            .clip(CircleShape)
            .background(if (isSelected) tokens.primary else tokens.surfaceElevated)
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 9.dp),
    ) {
        if (icon != null) {
            Icon(
                icon,
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

// --- Azkar content ---

/**
 * The way into the counting session, kept at the top of the list rather than
 * on every card: starting a session is a per-category action, and repeating
 * it on every card would imply each one starts its own.
 */
@Composable
private fun AzkarContentSection(
    category: AzkarCategory?,
    items: List<AzkarItem>,
    isCompletedToday: Boolean,
    tokens: ColorTokens,
    locale: String,
    listState: LazyListState,
    focusItemId: String?,
    highlightedItemId: String?,
    onHighlightChange: (String?) -> Unit,
    onStartSession: (AzkarCategory) -> Unit,
) {
    if (items.isEmpty()) {
        BrandEmptyState(
            icon = Icons.Filled.Search,
            message = stringResource(AzkarR.string.azkar_search_empty),
            tokens = tokens,
        )
    } else {
        // Scrolls to and briefly highlights the item a content-reminder tap
        // named — a plain jump-to would land the reader on the right passage
        // with no sense of why THAT card, among a whole category of nearly
        // identical cards, is the one the notification meant. Keyed on the
        // item ids (not `items` itself) so this only re-runs when the actual
        // set of visible items changes, not on every recomposition.
        LaunchedEffect(items.map { it.id }, focusItemId) {
            val targetId = focusItemId ?: return@LaunchedEffect
            val index = items.indexOfFirst { it.id == targetId }
            if (index < 0) return@LaunchedEffect
            // The start-session row occupies index 0 when a category is shown.
            val listIndex = if (category != null) index + 1 else index
            listState.animateScrollToItem(listIndex)
            onHighlightChange(targetId)
            delay(2500)
            onHighlightChange(null)
        }
        LazyColumn(
            state = listState,
            verticalArrangement = Arrangement.spacedBy(12.dp),
            modifier = Modifier.fillMaxSize().padding(horizontal = 20.dp),
        ) {
            category?.let { cat ->
                item {
                    StartSessionRow(
                        category = cat,
                        isDone = isCompletedToday,
                        tokens = tokens,
                        onClick = { onStartSession(cat) },
                    )
                }
            }
            items(items, key = { it.id }) {
                AzkarEntryCard(it, tokens, locale, isHighlighted = it.id == highlightedItemId)
            }
            item { Spacer(Modifier.height(24.dp)) }
        }
    }
}

@Composable
private fun StartSessionRow(
    category: AzkarCategory,
    isDone: Boolean,
    tokens: ColorTokens,
    onClick: () -> Unit,
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(tokens.primary.copy(alpha = 0.09f))
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 13.dp),
    ) {
        Icon(
            imageVector = if (isDone) Icons.Filled.Check else Icons.Filled.PlayArrow,
            contentDescription = null,
            tint = tokens.primary,
            modifier = Modifier.size(22.dp),
        )
        Text(
            text = stringResource(AzkarR.string.azkar_start_session),
            color = tokens.primary,
            fontWeight = FontWeight.SemiBold,
            style = MaterialTheme.typography.bodyMedium,
            modifier = Modifier.weight(1f),
        )
        Text(
            text = "${category.items.size}",
            color = tokens.onSurfaceSecondary,
            style = MaterialTheme.typography.labelMedium,
        )
    }
}

@Composable
private fun AzkarEntryCard(item: AzkarItem, tokens: ColorTokens, locale: String, isHighlighted: Boolean = false) {
    ArabicContentCard(
        arabic = item.arabicText,
        tokens = tokens,
        label = item.title,
        badgeText = RepeatCountLabel.text(item.repeatCount, Locale(locale)),
        modifier = if (isHighlighted) {
            Modifier.border(2.5.dp, tokens.primary, RoundedCornerShape(20.dp))
        } else {
            Modifier
        },
    )
}

// --- Du'a content ---

@Composable
private fun DuaContentSection(
    duas: List<Dua>,
    isSearching: Boolean,
    isFavorite: (String) -> Boolean,
    onToggleFavorite: (String) -> Unit,
    tokens: ColorTokens,
) {
    if (duas.isEmpty()) {
        // Distinguishing these matters: "no matches" and "this category is
        // empty" look identical otherwise, and the first is the user's doing
        // while the second is ours.
        BrandEmptyState(
            icon = Icons.Filled.Search,
            message = stringResource(if (isSearching) DuaR.string.dua_no_results else DuaR.string.dua_empty),
            tokens = tokens,
        )
    } else {
        LazyColumn(
            verticalArrangement = Arrangement.spacedBy(12.dp),
            modifier = Modifier.fillMaxSize().padding(horizontal = 20.dp),
        ) {
            items(duas, key = { it.id }) { dua ->
                ArabicContentCard(
                    arabic = dua.arabicText,
                    tokens = tokens,
                    label = dua.displayTitle,
                    accessory = {
                        FavoriteChip(
                            isFavorite = isFavorite(dua.id),
                            tokens = tokens,
                            onClick = { onToggleFavorite(dua.id) },
                        )
                    },
                )
            }
            item { Spacer(Modifier.height(24.dp)) }
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
                if (isFavorite) DuaR.string.dua_unfavorite else DuaR.string.dua_favorite,
            ),
            tint = tint,
            modifier = Modifier.size(14.dp),
        )
    }
}
