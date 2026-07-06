package com.fatwabot.feature.hadith

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.fatwabot.core.content.HadithCollectionSummary

/** Collections browser (docs/features/hadith-collections.md screen 1) —
 * mirror of iOS HadithCollectionsScreen. */
@Composable
fun HadithCollectionsScreen(
    onCollectionSelected: (HadithCollectionSummary) -> Unit,
    viewModel: HadithViewModel = hiltViewModel(),
    locale: String = "ar",
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    LaunchedEffect(locale) { viewModel.loadCollections(locale) }

    if (state.collections.isEmpty()) {
        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            CircularProgressIndicator()
        }
    } else {
        LazyColumn(modifier = Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
            items(state.collections) { collection ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { onCollectionSelected(collection) }
                        .padding(horizontal = 16.dp, vertical = 14.dp),
                ) {
                    Column(modifier = Modifier.fillMaxWidth()) {
                        Text(collection.name, style = MaterialTheme.typography.bodyLarge)
                        Text(
                            "${state.readCount(collection.slug)}/${collection.entryCount} مقروء",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    if (state.isCompleted(collection.slug, collection.entryCount)) {
                        Icon(
                            Icons.Filled.CheckCircle,
                            contentDescription = "مكتمل",
                            tint = MaterialTheme.colorScheme.primary,
                        )
                    }
                }
            }
        }
    }
}
