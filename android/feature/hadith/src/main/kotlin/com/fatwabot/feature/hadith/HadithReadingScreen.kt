package com.fatwabot.feature.hadith

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
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

/** Reading view (docs/features/hadith-collections.md screen 2) — mirror of
 * iOS HadithReadingScreen: number badge, Arabic text, grading, benefit-note
 * card, prev/next navigation. */
@Composable
fun HadithReadingScreen(
    slug: String,
    viewModel: HadithViewModel = hiltViewModel(),
    locale: String = "ar",
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    LaunchedEffect(slug, locale) { viewModel.openCollection(slug, locale) }

    val entry = state.currentEntry ?: return
    val detail = state.currentDetail

    Column(modifier = Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
        Column(
            modifier = Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            horizontalAlignment = Alignment.End,
        ) {
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Surface(
                    color = MaterialTheme.colorScheme.primaryContainer,
                    shape = RoundedCornerShape(50),
                ) {
                    Text(
                        "الحديث رقم ${entry.number}",
                        modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp),
                        style = MaterialTheme.typography.labelMedium,
                    )
                }
                Text(entry.grading, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }

            Text(
                entry.arabicText,
                style = MaterialTheme.typography.titleMedium,
                textAlign = TextAlign.End,
                modifier = Modifier.fillMaxWidth().padding(top = 16.dp),
            )

            entry.translation?.let {
                Text(
                    it,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Start,
                    modifier = Modifier.fillMaxWidth().padding(top = 12.dp),
                )
            }

            entry.benefitNote?.let { note ->
                Surface(
                    color = MaterialTheme.colorScheme.primaryContainer,
                    shape = RoundedCornerShape(14.dp),
                    modifier = Modifier.fillMaxWidth().padding(top = 16.dp),
                ) {
                    Column(modifier = Modifier.padding(12.dp), horizontalAlignment = Alignment.End) {
                        Text(
                            "الفائدة",
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.primary,
                        )
                        Text(note, style = MaterialTheme.typography.bodySmall)
                    }
                }
            }

            if (entry.source.isNotEmpty()) {
                Text(
                    entry.source,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.End,
                    modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
                )
            }
        }

        Row(
            modifier = Modifier.fillMaxWidth().padding(16.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            OutlinedButton(
                onClick = viewModel::previous,
                enabled = state.currentIndex > 0,
                modifier = Modifier.weight(1f),
            ) { Text("السابق") }
            Button(
                onClick = viewModel::next,
                enabled = detail != null && state.currentIndex < detail.entries.size - 1,
                modifier = Modifier.weight(1f),
            ) { Text("التالي") }
        }
    }
}
