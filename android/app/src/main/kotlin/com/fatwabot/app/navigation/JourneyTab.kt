package com.fatwabot.app.navigation

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.EmojiEvents
import androidx.compose.material.icons.filled.History
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.annotation.StringRes
import androidx.compose.runtime.Composable
import androidx.compose.ui.res.stringResource
import com.fatwabot.app.R
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.hilt.navigation.compose.hiltViewModel
import com.fatwabot.feature.gamification.GamificationScreen
import com.fatwabot.feature.leaderboard.LeaderboardScreen
import com.fatwabot.feature.searchhistory.SearchHistoryScreen

/** Journey tab: My Progress (Gamification) plus toolbar entry points into
 * Leaderboards and Search History — mirrors iOS RootTabView's Journey toolbar. */
private enum class JourneyDestination(@StringRes val titleRes: Int) {
    LEADERBOARD(R.string.journey_leaderboards),
    SEARCH_HISTORY(R.string.journey_search_history),
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun JourneyTab() {
    var destination by remember { mutableStateOf<JourneyDestination?>(null) }

    when (destination) {
        null -> Scaffold(
            topBar = {
                TopAppBar(
                    title = { Text(stringResource(R.string.journey_title)) },
                    actions = {
                        IconButton(onClick = { destination = JourneyDestination.LEADERBOARD }) {
                            Icon(Icons.Filled.EmojiEvents, contentDescription = stringResource(R.string.journey_leaderboards))
                        }
                        IconButton(onClick = { destination = JourneyDestination.SEARCH_HISTORY }) {
                            Icon(Icons.Filled.History, contentDescription = stringResource(R.string.journey_search_history))
                        }
                    },
                )
            },
        ) { padding ->
            Box(modifier = Modifier.padding(padding)) { GamificationScreen(viewModel = hiltViewModel()) }
        }
        JourneyDestination.LEADERBOARD -> JourneyDetailScaffold(
            title = stringResource(JourneyDestination.LEADERBOARD.titleRes),
            onBack = { destination = null },
        ) { LeaderboardScreen(viewModel = hiltViewModel()) }
        JourneyDestination.SEARCH_HISTORY -> JourneyDetailScaffold(
            title = stringResource(JourneyDestination.SEARCH_HISTORY.titleRes),
            onBack = { destination = null },
        ) { SearchHistoryScreen(viewModel = hiltViewModel()) }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun JourneyDetailScaffold(title: String, onBack: () -> Unit, content: @Composable () -> Unit) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(title) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.common_back))
                    }
                },
            )
        },
    ) { padding ->
        Box(modifier = Modifier.padding(padding)) { content() }
    }
}
