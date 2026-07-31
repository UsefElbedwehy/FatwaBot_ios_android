package com.fatwabot.feature.dua

import android.content.Intent
import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material.icons.filled.MenuBook
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.filled.TextFields
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.fatwabot.core.content.Dua
import com.fatwabot.core.designsystem.ArchIconBadge
import com.fatwabot.core.designsystem.BrandCard
import com.fatwabot.core.designsystem.DarkTokens
import com.fatwabot.core.designsystem.LightTokens
import com.fatwabot.core.designsystem.brandScreenBackground
import com.fatwabot.feature.dua.R

/** Reading view (docs/features/dua.md screen 3) — mirror of iOS
 * DuaReadingScreen: Arabic text, translation, source, favorite toggle, share. */
@Composable
fun DuaReadingScreen(
    dua: Dua,
    viewModel: DuaViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val context = LocalContext.current
    val isFavorite = state.isFavorite(dua.id)
    val tokens = if (isSystemInDarkTheme()) DarkTokens else LightTokens
    var showTransliteration by remember { mutableStateOf(true) }

    Box(modifier = Modifier.fillMaxSize().brandScreenBackground(tokens)) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.End,
            ) {
                IconButton(onClick = { viewModel.toggleFavorite(dua.id) }) {
                    Icon(
                        if (isFavorite) Icons.Filled.Favorite else Icons.Filled.FavoriteBorder,
                        contentDescription = stringResource(R.string.dua_favorite),
                        tint = tokens.primary,
                    )
                }
                IconButton(onClick = { shareDua(context, dua) }) {
                    Icon(Icons.Filled.Share, contentDescription = stringResource(R.string.dua_share), tint = tokens.primary)
                }
                if (dua.transliteration != null) {
                    IconButton(onClick = { showTransliteration = !showTransliteration }) {
                        Icon(
                            Icons.Filled.TextFields,
                            contentDescription = stringResource(R.string.dua_show_transliteration),
                            tint = if (showTransliteration) tokens.primary else tokens.onSurfaceSecondary,
                        )
                    }
                }
            }

            // Title header with arch-badged icon.
            Column(
                modifier = Modifier.fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                ArchIconBadge(icon = Icons.Filled.AutoAwesome, size = 72.dp, tokens = tokens)
                Text(
                    dua.displayTitle,
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    color = tokens.onSurface,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth(),
                )
            }

            // Arabic dua — large, reverent, elevated centerpiece.
            Text(
                dua.arabicText,
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.SemiBold,
                color = tokens.onSurface,
                textAlign = TextAlign.End,
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(24.dp))
                    .background(
                        Brush.linearGradient(listOf(tokens.primaryContainer, tokens.surfaceElevated)),
                    )
                    .border(1.dp, tokens.primary.copy(alpha = 0.15f), RoundedCornerShape(24.dp))
                    .padding(24.dp),
            )

            dua.transliteration?.let { transliteration ->
                if (showTransliteration) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(18.dp))
                            .background(tokens.primaryContainer.copy(alpha = 0.4f))
                            .border(1.dp, tokens.outline.copy(alpha = 0.5f), RoundedCornerShape(18.dp))
                            .padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(6.dp),
                    ) {
                        Text(
                            stringResource(R.string.dua_transliteration_label),
                            style = MaterialTheme.typography.labelMedium,
                            fontWeight = FontWeight.SemiBold,
                            color = tokens.accent,
                        )
                        Text(
                            transliteration,
                            style = MaterialTheme.typography.bodyMedium,
                            fontStyle = FontStyle.Italic,
                            color = tokens.onSurfaceSecondary,
                            modifier = Modifier.fillMaxWidth(),
                        )
                    }
                }
            }

            dua.translation?.let { translation ->
                BrandCard(tokens = tokens) {
                    Text(
                        translation,
                        style = MaterialTheme.typography.bodyLarge,
                        color = tokens.onSurface,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            }

            if (dua.source.isNotEmpty()) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.End,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        dua.source,
                        style = MaterialTheme.typography.labelSmall,
                        color = tokens.onSurfaceSecondary,
                        textAlign = TextAlign.End,
                    )
                    Spacer(Modifier.size(8.dp))
                    Icon(
                        Icons.Filled.MenuBook,
                        contentDescription = null,
                        tint = tokens.accent,
                        modifier = Modifier.size(14.dp),
                    )
                }
            }
        }
    }
}

private fun shareDua(context: android.content.Context, dua: Dua) {
    val text = listOfNotNull(dua.title, dua.arabicText, dua.translation, dua.source.ifEmpty { null })
        .joinToString("\n\n")
    val intent = Intent(Intent.ACTION_SEND).apply {
        type = "text/plain"
        putExtra(Intent.EXTRA_TEXT, text)
    }
    context.startActivity(Intent.createChooser(intent, null))
}
