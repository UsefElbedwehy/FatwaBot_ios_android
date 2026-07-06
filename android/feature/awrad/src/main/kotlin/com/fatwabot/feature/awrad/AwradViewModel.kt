package com.fatwabot.feature.awrad

import androidx.lifecycle.ViewModel
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
        val current = _state.value.progress
        val index = current.indexOfFirst { it.wirdId == wirdId && it.dateKey == key }
        val updated = if (index >= 0) {
            current.toMutableList().apply { this[index] = this[index].copy(count = this[index].count + amount) }
        } else {
            current + WirdDailyProgress(wirdId, key, amount)
        }
        store.saveProgress(updated)
        _state.update { it.copy(progress = updated) }
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
        return true
    }

    /** Archives without deleting historical progress — stats remain accurate. */
    fun archiveWird(wirdId: String) {
        val updated = _state.value.wirds.map {
            if (it.id == wirdId) it.copy(archivedAtEpochSeconds = clock.now().epochSeconds) else it
        }
        store.saveWirds(updated)
        _state.update { it.copy(wirds = updated) }
    }

    private fun todayKey(): String = dateKey(clock.now().epochSeconds)

    companion object {
        private val formatter = DateTimeFormatter.ofPattern("yyyy-MM-dd")

        fun dateKey(epochSeconds: Long, zone: ZoneId = ZoneId.systemDefault()): String =
            Instant.ofEpochSecond(epochSeconds).atZone(zone).format(formatter)
    }
}
