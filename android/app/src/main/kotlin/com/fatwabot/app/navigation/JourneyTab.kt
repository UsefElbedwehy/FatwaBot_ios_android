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
import androidx.compose.runtime.Composable
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
private enum class JourneyDestination(val title: String) {
    LEADERBOARD("لوحات المتصدرين"),
    SEARCH_HISTORY("سجل البحث"),
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun JourneyTab() {
    var destination by remember { mutableStateOf<JourneyDestination?>(null) }

    when (destination) {
        null -> Scaffold(
            topBar = {
                TopAppBar(
                    title = { Text("مسيرتك") },
                    actions = {
                        IconButton(onClick = { destination = JourneyDestination.LEADERBOARD }) {
                            Icon(Icons.Filled.EmojiEvents, contentDescription = "لوحات المتصدرين")
                        }
                        IconButton(onClick = { destination = JourneyDestination.SEARCH_HISTORY }) {
                            Icon(Icons.Filled.History, contentDescription = "سجل البحث")
                        }
                    },
                )
            },
        ) { padding ->
            Box(modifier = Modifier.padding(padding)) { GamificationScreen(viewModel = hiltViewModel()) }
        }
        JourneyDestination.LEADERBOARD -> JourneyDetailScaffold(
            title = JourneyDestination.LEADERBOARD.title,
            onBack = { destination = null },
        ) { LeaderboardScreen(viewModel = hiltViewModel()) }
        JourneyDestination.SEARCH_HISTORY -> JourneyDetailScaffold(
            title = JourneyDestination.SEARCH_HISTORY.title,
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
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "رجوع")
                    }
                },
            )
        },
    ) { padding ->
        Box(modifier = Modifier.padding(padding)) { content() }
    }
}
