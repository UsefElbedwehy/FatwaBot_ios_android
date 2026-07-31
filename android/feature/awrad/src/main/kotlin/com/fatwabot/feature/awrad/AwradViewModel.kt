package com.fatwabot.feature.awrad

import androidx.lifecycle.ViewModel
import com.fatwabot.core.common.ActivityEventRecording
import com.fatwabot.core.common.HapticsProviding
import com.fatwabot.core.common.NoopActivityEventRecording
import com.fatwabot.core.content.ContentService
import com.fatwabot.core.content.WirdTemplate
import dagger.hilt.android.lifecycle.HiltViewModel
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.datetime.Clock

/**
 * Daily-board state machine — mirror of iOS AwradViewModel
 * (docs/features/awrad.md). Template loading from ContentKit is a thin
 * synchronous wrapper; board logic is unit-testable with hand-built fixtures.
 */
@HiltViewModel
class AwradViewModel @Inject constructor(
    private val contentService: ContentService?,
    private val store: WirdStoring,
    private val clock: Clock,
    private val haptics: HapticsProviding,
    private val activityEvents: ActivityEventRecording = NoopActivityEventRecording(),
) : ViewModel() {

    data class UiState(
        val templates: List<WirdTemplate> = emptyList(),
        val wirds: List<Wird> = emptyList(),
        val progress: List<WirdDailyProgress> = emptyList(),
        val dayCompletions: List<WirdDayCompletionRecord> = emptyList(),
    ) {
        val activeWirds: List<Wird> get() = wirds.filter { it.isActive }
        val stats: WirdStats get() = WirdStats.compute(wirds, progress, dayCompletions)
    }

    private val _state = MutableStateFlow(
        UiState(
            wirds = store.loadWirds(),
            progress = store.loadProgress(),
            dayCompletions = store.loadDayCompletions(),
        ),
    )
    val state: StateFlow<UiState> = _state.asStateFlow()

    /**
     * Re-reads everything off the store. The view model outlives a backgrounding,
     * and [WirdCompletionResponder] writes to the same files from a notification
     * action while no UI is alive — without this the board would still show the
     * wird as outstanding after the user answered "yes" from the shade.
     */
    fun refresh() {
        _state.update {
            it.copy(
                wirds = store.loadWirds(),
                progress = store.loadProgress(),
                dayCompletions = store.loadDayCompletions(),
            )
        }
    }

    fun loadTemplates(locale: String) {
        _state.update { it.copy(templates = contentService?.wirdTemplates(locale)?.templates.orEmpty()) }
    }

    /** Today's tally for a wird (0 if untouched today). */
    fun todayCount(wirdId: String): Int =
        _state.value.progress.firstOrNull { it.wirdId == wirdId && it.dateKey == todayKey() }?.count ?: 0

    fun isDayCompletedToday(): Boolean = _state.value.dayCompletions.any { it.dateKey == todayKey() }

    fun createWird(template: WirdTemplate) {
        appendWird(
            Wird(
                name = template.name,
                type = template.type,
                target = template.defaultTarget,
                unit = template.defaultUnit,
                frequency = template.defaultFrequency,
                createdAtEpochSeconds = clock.now().epochSeconds,
            ),
        )
    }

    fun createCustomWird(name: String, type: String, target: Int, unit: String, frequency: String) {
        appendWird(
            Wird(
                name = name,
                type = type,
                target = maxOf(1, target),
                unit = unit,
                frequency = frequency,
                createdAtEpochSeconds = clock.now().epochSeconds,
            ),
        )
    }

    private fun appendWird(wird: Wird) {
        val updated = _state.value.wirds + wird
        store.saveWirds(updated)
        _state.update { it.copy(wirds = updated) }
    }

    /** Increments unconditionally — ticking past target does not error. */
    fun tick(wirdId: String, amount: Int = 1) {
        val key = todayKey()
        val countBefore = todayCount(wirdId)
        val current = _state.value.progress
        val index = current.indexOfFirst { it.wirdId == wirdId && it.dateKey == key }
        val updated = if (index >= 0) {
            current.toMutableList().apply { this[index] = this[index].copy(count = this[index].count + amount) }
        } else {
            current + WirdDailyProgress(wirdId, key, amount)
        }
        store.saveProgress(updated)
        _state.update { it.copy(progress = updated) }
        // `wird_id` matches what iOS has always sent. Without it the same user
        // action produces a different event on each platform, and any per-wird
        // gamification rule would silently only work for iOS.
        activityEvents.record(eventType = "wird_ticked", metadata = mapOf("wird_id" to wirdId))

        val wird = _state.value.wirds.firstOrNull { it.id == wirdId }
        val target = wird?.target
        val countAfter = countBefore + amount
        val justReachedTarget = target != null && countBefore < target && countAfter >= target
        if (justReachedTarget) {
            haptics.targetReached()
        } else {
            haptics.tick()
        }
        // Leaderboard currency (owner decision, 2026-07). The scoring engine
        // filters on event type alone — it cannot look inside metadata — so
        // "rank only the four fixed slots" needs its own event rather than a
        // filter over `wird_ticked`.
        //
        // Ranking on `wird_day_completed` instead would be unfair in both
        // directions: it is all-or-nothing over *every* active wird, so a user
        // with one trivial custom wird earns it more easily than a user with
        // ten. The fixed four are on every board by construction, which is what
        // makes them comparable between users at all.
        if (justReachedTarget && wird?.isFixed == true) {
            activityEvents.record(eventType = "fixed_wird_completed", metadata = mapOf("wird_id" to wirdId))
        }
    }

    /** Records today's completion only if every *active* wird has reached its
     * target today; idempotent. Returns whether completion was recorded now. */
    fun markDayComplete(): Boolean {
        val key = todayKey()
        val current = _state.value
        if (current.dayCompletions.any { it.dateKey == key }) return false
        val active = current.activeWirds
        if (active.isEmpty() || !active.all { todayCount(it.id) >= it.target }) return false
        val record = WirdDayCompletionRecord(key, clock.now().epochSeconds)
        store.recordDayCompletion(record)
        _state.update { it.copy(dayCompletions = it.dayCompletions + record) }
        activityEvents.record(eventType = "wird_day_completed")
        haptics.targetReached()
        return true
    }

    /**
     * Archives without deleting historical progress — stats remain accurate.
     *
     * Returns `false`, changing nothing, for one of the four fixed slots: those
     * are on every board by definition, so archiving one is not a user choice to
     * honour. [SeededWirdStore] would undo it on the next read anyway; refusing
     * here means the UI never briefly shows a state that is about to be reverted.
     */
    fun archiveWird(wirdId: String): Boolean {
        val index = _state.value.wirds.indexOfFirst { it.id == wirdId }
        if (index < 0) return false
        if (_state.value.wirds[index].isFixed) return false
        val updated = _state.value.wirds.toMutableList().apply {
            this[index] = this[index].copy(archivedAtEpochSeconds = clock.now().epochSeconds)
        }
        store.saveWirds(updated)
        _state.update { it.copy(wirds = updated) }
        return true
    }

    private fun todayKey(): String = dateKey(clock.now().epochSeconds)

    companion object {
        private val formatter = DateTimeFormatter.ofPattern("yyyy-MM-dd")

        fun dateKey(epochSeconds: Long, zone: ZoneId = ZoneId.systemDefault()): String =
            Instant.ofEpochSecond(epochSeconds).atZone(zone).format(formatter)
    }
}
