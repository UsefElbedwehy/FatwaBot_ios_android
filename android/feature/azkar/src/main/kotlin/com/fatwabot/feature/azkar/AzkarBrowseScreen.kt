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
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Clear
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
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.fatwabot.core.content.AzkarCategory
import com.fatwabot.core.content.AzkarItem
import com.fatwabot.core.designsystem.ArabicContentCard
import com.fatwabot.core.designsystem.BrandEmptyState
import com.fatwabot.core.designsystem.ColorTokens
import com.fatwabot.core.designsystem.DarkTokens
import com.fatwabot.core.designsystem.LightTokens
import com.fatwabot.core.designsystem.RepeatCountLabel
import com.fatwabot.core.designsystem.brandScreenBackground
import java.util.Locale

/**
 * Browsing the azkar corpus: category chips, search, and every entry in the
 * selected category as a scannable card. Mirror of iOS `AzkarBrowseScreen`.
 *
 * ## Why this exists next to the counting session
 * [AzkarSessionScreen] shows one dhikr at a time behind a counter, which is the
 * right shape for *performing* adhkar and is what feeds the streak. It is the
 * wrong shape for finding one — you could not see what a category contained
 * without counting through it, nor copy a single du'a without starting a session
 * you did not want. The session is still reachable from the top of the list.
 *
 * ## Presentation
 * Every entry is an [ArabicContentCard] — the same component Du'a and Hadith
 * use, so the same passage looks identical wherever it is reached from. The card
 * carries the passage and nothing else; see its documentation for what was
 * deliberately taken off this surface and why.
 */
@Composable
fun AzkarBrowseScreen(
    onStartSession: (AzkarCategory) -> Unit,
    viewModel: AzkarViewModel = hiltViewModel(),
    locale: String = "ar",
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val tokens = if (isSystemInDarkTheme()) DarkTokens else LightTokens
    var selectedCategoryId by remember { mutableStateOf<String?>(null) }
    var query by remember { mutableStateOf("") }

    LaunchedEffect(locale) { viewModel.loadCategories(locale) }

    val selected = state.categories.firstOrNull { it.id == selectedCategoryId }
        ?: state.categories.firstOrNull()
    val visible = AzkarSearch.filter(selected?.items.orEmpty(), query)

    Column(modifier = Modifier.fillMaxSize().brandScreenBackground(tokens)) {
        SearchField(query, tokens, onChange = { query = it })
        CategoryChips(
            categories = state.categories,
            selectedId = selected?.id,
            tokens = tokens,
            onSelect = {
                selectedCategoryId = it
                // A query from the previous category almost never applies to the
                // next one, and leaving it set shows an empty list that looks
                // like the category itself is empty.
                query = ""
            },
        )

        when {
            state.categories.isEmpty() && !state.hasLoadedCategories -> Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center,
            ) { CircularProgressIndicator(color = tokens.primary) }

            state.categories.isEmpty() -> BrandEmptyState(
                icon = Icons.Filled.MenuBook,
                message = stringResource(R.string.azkar_empty_message),
                tokens = tokens,
            )

            visible.isEmpty() -> BrandEmptyState(
                icon = Icons.Filled.Search,
                message = stringResource(R.string.azkar_search_empty),
                tokens = tokens,
            )

            else -> LazyColumn(
                verticalArrangement = Arrangement.spacedBy(12.dp),
                modifier = Modifier.fillMaxSize().padding(horizontal = 20.dp),
            ) {
                selected?.let { category ->
                    item {
                        StartSessionRow(
                            category = category,
                            isDone = viewModel.isCompletedToday(category.id),
                            tokens = tokens,
                            onClick = { onStartSession(category) },
                        )
                    }
                }
                items(visible, key = { it.id }) { EntryCard(it, tokens, locale) }
                item { Spacer(Modifier.height(24.dp)) }
            }
        }
    }
}

@Composable
private fun SearchField(query: String, tokens: ColorTokens, onChange: (String) -> Unit) {
    TextField(
        value = query,
        onValueChange = onChange,
        singleLine = true,
        placeholder = { Text(stringResource(R.string.azkar_search_placeholder)) },
        leadingIcon = { Icon(Icons.Filled.Search, contentDescription = null) },
        trailingIcon = {
            if (query.isNotEmpty()) {
                IconButton(onClick = { onChange("") }) {
                    Icon(
                        Icons.Filled.Clear,
                        contentDescription = stringResource(R.string.azkar_search_clear),
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
    categories: List<AzkarCategory>,
    selectedId: String?,
    tokens: ColorTokens,
    onSelect: (String) -> Unit,
) {
    LazyRow(
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 20.dp),
        modifier = Modifier.fillMaxWidth().padding(bottom = 14.dp),
    ) {
        items(categories, key = { it.id }) { category ->
            val isSelected = category.id == selectedId
            Text(
                text = category.name,
                color = if (isSelected) tokens.onPrimary else tokens.onSurface,
                fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
                style = MaterialTheme.typography.bodyMedium,
                modifier = Modifier
                    .clip(CircleShape)
                    .background(if (isSelected) tokens.primary else tokens.surfaceElevated)
                    .clickable { onSelect(category.id) }
                    .padding(horizontal = 16.dp, vertical = 9.dp),
            )
        }
    }
}

/**
 * The way into the counting session, kept at the top of the list rather than on
 * every card: starting a session is a per-category action, and repeating it on
 * all 26 cards would imply each one starts its own.
 */
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
            text = stringResource(R.string.azkar_start_session),
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

/**
 * One entry: title, repeat marker, matn, copy. Nothing else.
 *
 * ## What used to be here
 * The card also rendered `item.source` and `item.translation`. Both are gone at
 * the owner's direction — "remove the red text and the english text, keep only
 * the main".
 *
 * `source` was never the short attribution its name suggests: across the corpus
 * it holds a 90–400 character takhrij chain
 * («عن أنس يرفعه: … أبو داود، برقم ٣٦٧٧، وحسنه الألباني…»), and because it was
 * the fallback whenever an entry had no title in the active locale, most cards
 * opened with a paragraph of isnad in brand maroon before the reader reached the
 * dhikr. Titles now cover the corpus, so the fallback is gone too — an untitled
 * entry simply shows its matn.
 */
@Composable
private fun EntryCard(item: AzkarItem, tokens: ColorTokens, locale: String) {
    ArabicContentCard(
        arabic = item.arabicText,
        tokens = tokens,
        label = item.title,
        badgeText = RepeatCountLabel.text(item.repeatCount, Locale(locale)),
    )
}

