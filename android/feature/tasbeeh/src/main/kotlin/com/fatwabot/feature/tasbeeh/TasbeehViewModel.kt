package com.fatwabot.feature.tasbeeh

import androidx.lifecycle.ViewModel
import dagger.hilt.android.lifecycle.HiltViewModel
import java.util.UUID
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.datetime.Clock

/**
 * State machine for the Tasbeeh screen — mirror of iOS TasbeehViewModel.
 * Counting past target does not reset or block; the confirm-before-reset UX
 * decision lives in the UI, driven by `state.count > 0`.
 */
@HiltViewModel
class TasbeehViewModel @Inject constructor(
    private val haptics: HapticsProviding,
    private val store: TasbeehHistoryStoring,
    private val clock: Clock,
) : ViewModel() {

    data class UiState(
        val selectedPreset: DhikrPreset = DhikrPreset.bundled[0],
        val customText: String = "",
        val count: Int = 0,
        val target: Int = 33,
        val history: List<TasbeehHistoryEntry> = emptyList(),
        val justReachedTarget: Boolean = false,
    ) {
        val displayText: String
            get() = if (selectedPreset.id == DhikrPreset.CUSTOM.id) customText else selectedPreset.arabicText
        val stats: TasbeehStats
            get() = TasbeehStats.from(history)
    }

    private val _state = MutableStateFlow(UiState(history = store.load()))
    val state: StateFlow<UiState> = _state.asStateFlow()

    fun select(preset: DhikrPreset) {
        _state.update { it.copy(selectedPreset = preset, count = 0, justReachedTarget = false) }
    }

    fun updateCustomText(text: String) {
        _state.update { it.copy(customText = text) }
    }

    fun changeTarget(value: Int) {
        _state.update { it.copy(target = maxOf(1, value)) }
    }

    fun increment() {
        val current = _state.value
        val newCount = current.count + 1
        val justReached = current.count < current.target && newCount >= current.target
        if (justReached) haptics.targetReached() else haptics.tick()
        _state.update { it.copy(count = newCount, justReachedTarget = justReached) }
    }

    fun acknowledgeTargetReached() {
        _state.update { it.copy(justReachedTarget = false) }
    }

    fun reset() {
        _state.update { it.copy(count = 0, justReachedTarget = false) }
    }

    /** Records actual count (not target) to history; starts a fresh set. */
    fun completeSet() {
        val current = _state.value
        if (current.count <= 0) return
        val entry = TasbeehHistoryEntry(
            id = UUID.randomUUID().toString(),
            presetId = if (current.selectedPreset.id == DhikrPreset.CUSTOM.id) null else current.selectedPreset.id,
            customText = if (current.selectedPreset.id == DhikrPreset.CUSTOM.id) current.customText else null,
            target = current.target,
            actualCount = current.count,
            completedAtEpochSeconds = clock.now().epochSeconds,
        )
        val newHistory = current.history + entry
        store.save(newHistory)
        _state.update { it.copy(count = 0, justReachedTarget = false, history = newHistory) }
    }
}
