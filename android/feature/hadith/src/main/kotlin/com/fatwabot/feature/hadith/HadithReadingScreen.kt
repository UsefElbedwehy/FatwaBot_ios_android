package com.fatwabot.feature.hadith

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Lightbulb
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material3.Button
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.fatwabot.feature.hadith.R
import com.fatwabot.core.designsystem.BrandCard
import com.fatwabot.core.designsystem.DarkTokens
import com.fatwabot.core.designsystem.LightTokens
import com.fatwabot.core.designsystem.brandScreenBackground

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
    val tokens = if (isSystemInDarkTheme()) DarkTokens else LightTokens

    LaunchedEffect(slug, locale) { viewModel.openCollection(slug, locale) }

    val entry = state.currentEntry ?: return
    val detail = state.currentDetail

    Column(modifier = Modifier.fillMaxSize().brandScreenBackground(tokens)) {
        Column(
            modifier = Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(20.dp),
            horizontalAlignment = Alignment.End,
            verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Surface(
                    color = tokens.primaryContainer,
                    shape = RoundedCornerShape(50),
                ) {
                    Text(
                        stringResource(R.string.hadith_number, entry.number),
                        modifier = Modifier.padding(horizontal = 12.dp, vertical = 5.dp),
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = tokens.primary,
                    )
                }
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    Icon(Icons.Filled.Verified, contentDescription = null, tint = tokens.accent, modifier = Modifier.size(14.dp))
                    Text(entry.grading, style = MaterialTheme.typography.labelMedium, color = tokens.accent)
                }
            }

            // Reverent centerpiece: the hadith text in an elevated gradient card.
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .shadow(elevation = 8.dp, shape = RoundedCornerShape(22.dp), clip = false)
                    .background(
                        Brush.verticalGradient(
                            listOf(tokens.surfaceElevated, tokens.primaryContainer.copy(alpha = 0.5f)),
                        ),
                        RoundedCornerShape(22.dp),
                    )
                    .border(1.dp, tokens.primary.copy(alpha = 0.12f), RoundedCornerShape(22.dp))
                    .padding(20.dp),
            ) {
                Text(
                    entry.arabicText,
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Medium,
                    lineHeight = 34.sp,
                    textAlign = TextAlign.End,
                    color = tokens.onSurface,
                    modifier = Modifier.fillMaxWidth(),
                )
            }

            entry.translation?.let {
                BrandCard(tokens = tokens) {
                    Text(
                        it,
                        style = MaterialTheme.typography.bodyMedium,
                        color = tokens.onSurface,
                        textAlign = TextAlign.Start,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            }

            entry.benefitNote?.let { note ->
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(tokens.accent.copy(alpha = 0.10f), RoundedCornerShape(18.dp))
                        .border(1.dp, tokens.accent.copy(alpha = 0.3f), RoundedCornerShape(18.dp))
                        .padding(16.dp),
                    horizontalAlignment = Alignment.End,
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        Icon(Icons.Filled.Lightbulb, contentDescription = null, tint = tokens.accent, modifier = Modifier.size(16.dp))
                        Text(
                            stringResource(R.string.hadith_benefit),
                            style = MaterialTheme.typography.labelMedium,
                            fontWeight = FontWeight.SemiBold,
                            color = tokens.accent,
                        )
                    }
                    Text(
                        note,
                        style = MaterialTheme.typography.bodyMedium,
                        color = tokens.onSurface,
                        textAlign = TextAlign.End,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            }

            if (entry.source.isNotEmpty()) {
                Text(
                    entry.source,
                    style = MaterialTheme.typography.labelSmall,
                    color = tokens.onSurfaceSecondary,
                    textAlign = TextAlign.End,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        }

        Row(
            modifier = Modifier.fillMaxWidth().padding(20.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            OutlinedButton(
                onClick = viewModel::previous,
                enabled = state.currentIndex > 0,
                modifier = Modifier.weight(1f),
            ) { Text(stringResource(R.string.hadith_previous)) }
            Button(
                onClick = viewModel::next,
                enabled = detail != null && state.currentIndex < detail.entries.size - 1,
                modifier = Modifier.weight(1f),
            ) { Text(stringResource(R.string.hadith_next)) }
        }
    }
}
