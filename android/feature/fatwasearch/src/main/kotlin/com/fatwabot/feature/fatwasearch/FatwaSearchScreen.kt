package com.fatwabot.feature.fatwasearch

import androidx.compose.foundation.background
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
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Chat
import androidx.compose.material.icons.automirrored.filled.MenuBook
import androidx.compose.material.icons.automirrored.filled.Help
import androidx.compose.material.icons.automirrored.filled.MenuBook
import androidx.compose.material.icons.filled.Book
import androidx.compose.material.icons.filled.QuestionAnswer
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.fatwabot.core.designsystem.ArabicContentCard
import com.fatwabot.core.designsystem.BrandCard
import com.fatwabot.core.designsystem.BrandEmptyState
import com.fatwabot.core.designsystem.BrandMark
import com.fatwabot.core.designsystem.BrandSectionHeader
import com.fatwabot.core.designsystem.ColorTokens
import com.fatwabot.core.designsystem.MarkdownText
import com.fatwabot.core.designsystem.DarkTokens
import com.fatwabot.core.designsystem.LightTokens
import com.fatwabot.core.designsystem.brandScreenBackground
import kotlinx.coroutines.launch

private fun FatwaSearchMode.icon(): ImageVector = when (this) {
    FatwaSearchMode.FATWA -> Icons.Filled.Search
    FatwaSearchMode.HADITH -> Icons.AutoMirrored.Filled.MenuBook
    FatwaSearchMode.GENERAL -> Icons.Filled.QuestionAnswer
}

/** The search screen: brand header, mode chips, question field.
 *
 * M5.1, from the client's feedback: choosing a mode is selecting a chip and
 * never navigates, and tapping the field opens the keyboard where you already
 * are. Pressing بحث *does* navigate — to [FatwaSearchResultScreen] — because the
 * complaint was about being pushed to a second *search* page, not about results
 * having a page of their own.
 *
 * The host decides which of the two is on screen by watching `phase`.
 */
@Composable
fun FatwaSearchScreen(
    viewModel: FatwaSearchViewModel,
    /** Branding above the chips. Home passes its logo/wordmark header through
     *  here rather than wrapping this screen, so the whole page scrolls as one. */
    header: @Composable () -> Unit = {},
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val tokens = if (isSystemInDarkTheme()) DarkTokens else LightTokens
    val scope = rememberCoroutineScope()

    Column(
        modifier = Modifier
            // fillMaxSize, not fillMaxWidth: the background is painted on this
            // box, so with short content it stopped at the content's height and
            // the rest of the screen showed the raw window colour.
            .fillMaxSize()
            .brandScreenBackground(tokens)
            .verticalScroll(rememberScrollState())
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        header()
        ModeChips(selectedMode = state.mode, onSelect = viewModel::setMode, tokens = tokens)
        QuestionField(
            mode = state.mode,
            question = state.question,
            isLoading = false,
            onQuestionChange = viewModel::updateQuestion,
            onSubmit = { scope.launch { viewModel.submit() } },
            tokens = tokens,
        )
        BrandEmptyState(
            icon = state.mode.icon(),
            message = stringResource(state.mode.hintRes()),
            tokens = tokens,
        )
    }
}

/** The result page — everything after بحث: the dhikr loading view, the M5.1
 *  result card, or the failure states. Its own page, with its own back. */
@Composable
fun FatwaSearchResultScreen(
    viewModel: FatwaSearchViewModel,
    onContact: () -> Unit = {},
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val tokens = if (isSystemInDarkTheme()) DarkTokens else LightTokens
    val scope = rememberCoroutineScope()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .brandScreenBackground(tokens)
            .verticalScroll(rememberScrollState())
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        when (val phase = state.phase) {
            // Idle never renders here — the host swaps back to the search
            // screen the moment the phase returns to it.
            is FatwaSearchViewModel.Phase.Idle -> Unit
            is FatwaSearchViewModel.Phase.Loading -> DhikrLoadingView(tokens)
            is FatwaSearchViewModel.Phase.Unavailable -> UnavailableCard(tokens)
            is FatwaSearchViewModel.Phase.Error -> ErrorCard(
                // Deliberately not `phase.message`: that is the exception's own
                // text, which reached users as "Transport(detail=timeout)". It
                // stays on the phase for logging and is never shown.
                message = stringResource(R.string.fatwa_search_error_generic),
                onRetry = { scope.launch { viewModel.submit() } },
                tokens = tokens,
            )
            is FatwaSearchViewModel.Phase.Result -> SearchResultView(
                response = phase.response,
                isDark = isSystemInDarkTheme(),
                tokens = tokens,
                onAskAgain = viewModel::reset,
                onContact = onContact,
            )
        }
    }
}

@Composable
private fun QuestionField(
    mode: FatwaSearchMode,
    question: String,
    isLoading: Boolean,
    onQuestionChange: (String) -> Unit,
    onSubmit: () -> Unit,
    tokens: ColorTokens,
) {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        TextField(
            value = question,
            onValueChange = onQuestionChange,
            enabled = !isLoading,
            placeholder = { Text(stringResource(mode.placeholderRes())) },
            leadingIcon = { Icon(mode.icon(), contentDescription = null, tint = tokens.onSurfaceSecondary) },
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
            keyboardActions = KeyboardActions(onSearch = { onSubmit() }),
            shape = RoundedCornerShape(14.dp),
            colors = TextFieldDefaults.colors(
                focusedContainerColor = tokens.surfaceElevated,
                unfocusedContainerColor = tokens.surfaceElevated,
                focusedIndicatorColor = Color.Transparent,
                unfocusedIndicatorColor = Color.Transparent,
            ),
            modifier = Modifier.fillMaxWidth(),
        )
        Button(
            onClick = onSubmit,
            enabled = !isLoading && question.isNotBlank(),
            colors = ButtonDefaults.buttonColors(containerColor = tokens.primary, contentColor = tokens.onPrimary),
            shape = RoundedCornerShape(14.dp),
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text(stringResource(R.string.fatwa_search_submit), fontWeight = FontWeight.SemiBold)
        }
    }
}

@Composable
private fun UnavailableCard(tokens: ColorTokens) {
    Column(
        modifier = Modifier.fillMaxWidth().padding(vertical = 40.dp, horizontal = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        BrandMark(color = tokens.primary, modifier = Modifier.size(width = 64.dp, height = 90.dp).padding(bottom = 4.dp))
        Text(
            stringResource(R.string.fatwa_search_unavailable_title),
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold,
            color = tokens.onSurface,
        )
        Text(
            stringResource(R.string.fatwa_search_unavailable_body),
            style = MaterialTheme.typography.bodyMedium,
            color = tokens.onSurfaceSecondary,
            textAlign = TextAlign.Center,
        )
    }
}

@Composable
private fun ErrorCard(
    message: String?,
    onRetry: () -> Unit, tokens: ColorTokens) {
    Column(
        modifier = Modifier.fillMaxWidth().padding(vertical = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Text(
            // The server's own message when it sent one — it explains what
            // actually failed. This was hardcoded to the generic string, so a
            // specific, actionable error was thrown away.
            message?.takeIf { it.isNotBlank() } ?: stringResource(R.string.fatwa_search_error_generic),
            style = MaterialTheme.typography.bodyMedium,
            color = tokens.onSurfaceSecondary,
            textAlign = TextAlign.Center,
        )
        TextButton(onClick = onRetry) {
            Text(stringResource(R.string.fatwa_search_retry), color = tokens.primary, fontWeight = FontWeight.SemiBold)
        }
    }
}

/** The three modes as selectable chips. Selecting one never navigates — that
 *  was the client's complaint about the old flow — and فتوى is selected by
 *  default because it is what most people come here for. */
@Composable
private fun ModeChips(
    selectedMode: FatwaSearchMode,
    onSelect: (FatwaSearchMode) -> Unit,
    tokens: ColorTokens,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        FatwaSearchMode.entries.forEach { mode ->
            val isSelected = mode == selectedMode
            Surface(
                color = if (isSelected) tokens.primary else tokens.surfaceElevated,
                shape = RoundedCornerShape(14.dp),
                onClick = { onSelect(mode) },
                // Announced as a selectable, not a button, so a screen reader
                // says whether it is on — the visual fill is the only other cue.
                modifier = Modifier.weight(1f).semantics { selected = isSelected },
            ) {
                Column(
                    modifier = Modifier.padding(vertical = 12.dp, horizontal = 8.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    Icon(
                        mode.icon(),
                        contentDescription = null,
                        tint = if (isSelected) tokens.onPrimary else tokens.primary,
                        modifier = Modifier.size(20.dp),
                    )
                    Text(
                        stringResource(mode.titleRes()),
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                        color = if (isSelected) tokens.onPrimary else tokens.onSurface,
                        textAlign = TextAlign.Center,
                        maxLines = 2,
                    )
                }
            }
        }
    }
}
