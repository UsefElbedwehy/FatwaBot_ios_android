package com.fatwabot.feature.gamification

import androidx.lifecycle.ViewModel
import com.fatwabot.core.common.GamificationWidgetSnapshot
import com.fatwabot.core.common.GamificationWidgetSnapshotStore
import com.fatwabot.core.network.AuthenticatedApiClientProtocol
import dagger.hilt.android.lifecycle.HiltViewModel
import java.util.TimeZone
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.serialization.json.Json

/** State machine for the Gamification screen (docs/features/gamification.md).
 * Renders server descriptors verbatim — no client-side scoring/streak math. */
@HiltViewModel
class GamificationViewModel @Inject constructor(
    private val client: AuthenticatedApiClientProtocol,
    private val recorder: GamificationEventRecorder?,
    private val widgetStore: GamificationWidgetSnapshotStore? = null,
    private val onWidgetSnapshotWritten: WidgetRefresh? = null,
) : ViewModel() {
    /** App-supplied hook to trigger Glance updateAll after a new snapshot. */
    fun interface WidgetRefresh {
        fun refresh()
    }

    private val json = Json { ignoreUnknownKeys = true }
    private val timezone: String = TimeZone.getDefault().id

    data class UiState(
        val profile: GamificationProfile = GamificationProfile.EMPTY,
        val isLoading: Boolean = false,
        val error: String? = null,
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    /** Refreshes the profile, keeping the current one visible while the fetch is
     * in flight (the spinner only shows while the profile is still empty). */
    suspend fun load() {
        _state.update { it.copy(isLoading = true, error = null) }
        // Flush any queued events first so a fresh profile reflects them.
        recorder?.flush()
        runCatching {
            val raw = client.getRaw("v1/gamification/profile", mapOf("timezone" to timezone))
            json.decodeFromString(GamificationProfile.serializer(), raw)
        }.fold(
            onSuccess = { profile ->
                _state.update { it.copy(profile = profile, isLoading = false) }
                writeWidgetSnapshot(profile)
            },
            onFailure = { error -> _state.update { it.copy(error = error.toString(), isLoading = false) } },
        )
    }

    /** Widgets show one headline streak/mission, not the full profile — the
     * longest current streak, and the first not-yet-complete daily mission
     * (falling back to the first daily mission if all are complete). */
    private fun writeWidgetSnapshot(profile: GamificationProfile) {
        val store = widgetStore ?: return
        val topStreak = profile.streaks.maxByOrNull { it.currentLength }?.let {
            GamificationWidgetSnapshot.Streak(it.name, it.currentLength, it.longestLength, it.graceRemaining)
        }
        val dailyMissions = profile.missions.filter { it.window == "daily" }
        val dailyChallenge = (dailyMissions.firstOrNull { it.progress < it.target } ?: dailyMissions.firstOrNull())?.let {
            GamificationWidgetSnapshot.DailyChallenge(it.name, it.progress, it.target)
        }
        store.write(GamificationWidgetSnapshot(topStreak, dailyChallenge, System.currentTimeMillis() / 1000))
        onWidgetSnapshotWritten?.refresh()
    }
}
