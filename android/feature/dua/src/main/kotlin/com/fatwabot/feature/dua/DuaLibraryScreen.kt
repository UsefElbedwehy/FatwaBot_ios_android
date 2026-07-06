package com.fatwabot.feature.dua

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.fatwabot.core.content.Dua
import com.fatwabot.core.content.DuaCategory

/** Library browse/search home (docs/features/dua.md screen 1) — mirror of
 * iOS DuaLibraryScreen. */
@Composable
fun DuaLibraryScreen(
    onDuaSelected: (Dua) -> Unit,
    viewModel: DuaViewModel = hiltViewModel(),
    locale: String = "ar",
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    LaunchedEffect(locale) { viewModel.loadCategories(locale) }

    LazyColumn(modifier = Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
        item {
            Row(
                modifier = Modifier.fillMaxWidth().padding(16.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(Icons.Filled.Search, contentDescription = null, tint = MaterialTheme.colorScheme.onSurfaceVariant)
                OutlinedTextField(
                    value = state.searchQuery,
                    onValueChange = viewModel::updateSearchQuery,
                    placeholder = { Text("ابحث في الأدعية…") },
                    modifier = Modifier.fillMaxWidth().padding(start = 8.dp),
                )
            }
        }

        val results = state.searchResults
        if (results != null) {
            if (results.isEmpty()) {
                item {
                    Text(
                        "لا توجد نتائج مطابقة",
                        modifier = Modifier.padding(16.dp),
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            } else {
                item { SectionHeader("نتائج البحث") }
                items(results) { dua -> DuaRow(dua, onClick = { onDuaSelected(dua) }) }
            }
        } else {
            if (state.favoriteDuas.isNotEmpty()) {
                item { SectionHeader("المفضلة") }
                items(state.favoriteDuas) { dua -> DuaRow(dua, onClick = { onDuaSelected(dua) }) }
            }
            state.categories.forEach { category: DuaCategory ->
                item { SectionHeader(category.name) }
                items(category.duas) { dua -> DuaRow(dua, onClick = { onDuaSelected(dua) }) }
            }
        }
    }
}

@Composable
private fun SectionHeader(title: String) {
    Text(
        title,
        style = MaterialTheme.typography.labelLarge,
        color = MaterialTheme.colorScheme.primary,
        textAlign = TextAlign.End,
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
    )
}

@Composable
private fun DuaRow(dua: Dua, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 10.dp),
    ) {
        Column(modifier = Modifier.fillMaxWidth()) {
            Text(dua.title, textAlign = TextAlign.End, modifier = Modifier.fillMaxWidth())
            if (dua.source.isNotEmpty()) {
                Text(
                    dua.source,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.End,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        }
    }
}
