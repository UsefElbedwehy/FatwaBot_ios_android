package com.fatwabot.feature.leaderboard

import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.EmojiEvents
import androidx.compose.material.icons.filled.PersonAddAlt
import androidx.compose.material.icons.filled.WifiOff
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.fatwabot.core.designsystem.BrandCard
import com.fatwabot.core.designsystem.BrandEmptyState
import com.fatwabot.core.designsystem.ColorTokens
import com.fatwabot.core.designsystem.DarkTokens
import com.fatwabot.core.designsystem.LightTokens
import com.fatwabot.core.designsystem.RankMedal
import com.fatwabot.core.designsystem.brandScreenBackground
import com.fatwabot.feature.leaderboard.R
import kotlinx.coroutines.launch

/** Leaderboards screen — mirror of iOS LeaderboardScreen
 * (docs/features/leaderboard.md). */
@Composable
fun LeaderboardScreen(viewModel: LeaderboardViewModel = hiltViewModel()) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val scope = rememberCoroutineScope()
    val tokens = if (isSystemInDarkTheme()) DarkTokens else LightTokens
    var joinTarget by remember { mutableStateOf<LeaderboardBoard?>(null) }

    LaunchedEffect(Unit) { viewModel.load() }

    Box(modifier = Modifier.fillMaxSize().brandScreenBackground(tokens)) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp),
        ) {
            state.error?.let { error -> NoticeCard(error, tokens) }

            if (state.boards.isNotEmpty()) {
                // Custom awrad are deliberately unranked (owner decision,
                // 2026-07). Saying so is the difference between a rule and a
                // user quietly concluding their effort doesn't register.
                NoticeCard(stringResource(R.string.leaderboard_scoring_notice), tokens)
            }

            state.boards.forEach { board ->
                BoardCard(
                    board = board,
                    tokens = tokens,
                    onJoin = { joinTarget = board },
                    onLeave = { scope.launch { viewModel.leave(board.key) } },
                )
            }

            if (!state.isLoading && state.boards.isEmpty() && state.error == null) {
                BrandEmptyState(
                    Icons.Filled.EmojiEvents,
                    stringResource(R.string.leaderboard_empty),
                    tokens = tokens,
                )
            }
        }
        if (state.isLoading && state.boards.isEmpty()) {
            CircularProgressIndicator(
                color = tokens.primary,
                modifier = Modifier.align(Alignment.Center),
            )
        }
    }

    joinTarget?.let { board ->
        JoinDialog(
            board = board,
            suggestedRegion = state.suggestedRegion,
            onDismiss = { joinTarget = null },
            onConfirm = { publishName, city ->
                joinTarget = null
                scope.launch { viewModel.join(board.key, publishName, city) }
            },
        )
    }
}

@Composable
private fun NoticeCard(error: String, tokens: ColorTokens) {
    BrandCard(tokens = tokens) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Icon(Icons.Filled.WifiOff, contentDescription = null, tint = tokens.accent)
            Text(error, style = MaterialTheme.typography.bodySmall, color = tokens.onSurfaceSecondary)
        }
    }
}

@Composable
private fun BoardCard(
    board: LeaderboardBoard,
    tokens: ColorTokens,
    onJoin: () -> Unit,
    onLeave: () -> Unit,
) {
    BrandCard(tokens = tokens, contentPadding = 18.dp) {
        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth().semantics(mergeDescendants = true) {},
                verticalAlignment = Alignment.Top,
            ) {
                Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                    Text(
                        board.name,
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        color = tokens.onSurface,
                    )
                    Text(
                        "${board.scope} · ${board.period}",
                        style = MaterialTheme.typography.bodySmall,
                        color = tokens.onSurfaceSecondary,
                    )
                }
                board.myRank?.let { rank ->
                    Text(
                        stringResource(R.string.leaderboard_my_rank, rank),
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = tokens.primary,
                        modifier = Modifier
                            .clip(RoundedCornerShape(50))
                            .background(tokens.primaryContainer)
                            .padding(horizontal = 10.dp, vertical = 5.dp),
                    )
                }
            }

            if (board.joined) {
                Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    board.entries.forEach { entry ->
                        EntryRow(entry, isMe = entry.rank == board.myRank, tokens = tokens)
                    }
                }
                OutlinedButton(
                    onClick = onLeave,
                    modifier = Modifier.fillMaxWidth(),
                    colors = ButtonDefaults.outlinedButtonColors(contentColor = tokens.primary),
                ) {
                    Text(stringResource(R.string.leaderboard_leave), fontWeight = FontWeight.Medium)
                }
            } else {
                Button(
                    onClick = onJoin,
                    modifier = Modifier.fillMaxWidth(),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = tokens.primary,
                        contentColor = tokens.onPrimary,
                    ),
                ) {
                    Icon(Icons.Filled.PersonAddAlt, contentDescription = null, modifier = Modifier.width(18.dp))
                    Spacer(Modifier.width(8.dp))
                    Text(stringResource(R.string.leaderboard_join), fontWeight = FontWeight.SemiBold)
                }
            }
        }
    }
}

@Composable
private fun EntryRow(entry: LeaderboardEntry, isMe: Boolean, tokens: ColorTokens) {
    val entryDescription = stringResource(R.string.leaderboard_entry_cd, entry.rank, entry.displayName, entry.score.toInt())
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(if (isMe) tokens.primary.copy(alpha = 0.08f) else Color.Transparent)
            .padding(horizontal = 8.dp, vertical = 8.dp)
            .semantics(mergeDescendants = true) {
                contentDescription = entryDescription
            },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        RankMedal(rank = entry.rank, tokens = tokens)
        Text(
            entry.displayName,
            modifier = Modifier.weight(1f),
            fontWeight = if (isMe) FontWeight.Bold else FontWeight.Normal,
            color = if (isMe) tokens.primary else tokens.onSurface,
        )
        Text(
            "${entry.score.toInt()}",
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.SemiBold,
            color = tokens.onSurfaceSecondary,
        )
    }
}

@Composable
private fun JoinDialog(
    board: LeaderboardBoard,
    /**
     * Derived from the prayer-times location. Not editable: the app already
     * knows where the user is, and asking them to type it invites typos that
     * silently fragment a city board — "Riyadh", "riyadh" and "الرياض" become
     * three leaderboards nobody is competing on. Client request, 2026-08-09.
     */
    suggestedRegion: LeaderboardRegion,
    onDismiss: () -> Unit,
    onConfirm: (Boolean, String?) -> Unit,
) {
    var publishName by remember { mutableStateOf(false) }
    val isCityScope = board.scope == "city"
    val isCountryScope = board.scope == "country"
    // Neither scope asks the user for anything now — both are derived — so the
    // only thing that can block a join is not knowing the region at all.
    val missingCountry = isCountryScope && suggestedRegion.countryCode == null
    val missingCity = isCityScope && suggestedRegion.city == null
    val missingRegion = missingCountry || missingCity
    // "مصر" rather than "EG". The code is an implementation detail of the API.
    val countryName = suggestedRegion.countryCode?.let {
        java.util.Locale("", it).getDisplayCountry(java.util.Locale.getDefault())
            .takeIf { name -> name.isNotBlank() } ?: it
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.leaderboard_join_title)) },
        text = {
            Column {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween,
                    modifier = Modifier.fillMaxWidth().semantics(mergeDescendants = true) {},
                ) {
                    Text(stringResource(R.string.leaderboard_publish_name))
                    Switch(checked = publishName, onCheckedChange = { publishName = it })
                }
                if (isCityScope && suggestedRegion.city != null) {
                    Text(stringResource(R.string.leaderboard_city, suggestedRegion.city))
                }
                if (isCountryScope && countryName != null) {
                    Text(stringResource(R.string.leaderboard_country, countryName))
                }
                if (missingRegion) {
                    // Previously the user could tap Join and the server answered
                    // 400 country_required — an error they had no way to act on.
                    Text(
                        stringResource(R.string.leaderboard_region_unavailable),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        },
        confirmButton = {
            TextButton(
                // null for both scopes: the view model derives the city from
                // the same location, so passing a copy here would be a second
                // source of truth.
                onClick = { onConfirm(publishName, null) },
                enabled = !missingRegion,
            ) { Text(stringResource(R.string.leaderboard_join)) }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.leaderboard_cancel)) } },
    )
}
