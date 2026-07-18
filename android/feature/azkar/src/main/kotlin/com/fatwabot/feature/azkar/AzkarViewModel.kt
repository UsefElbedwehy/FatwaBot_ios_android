package com.fatwabot.feature.azkar

import androidx.lifecycle.ViewModel
import com.fatwabot.core.common.ActivityEventRecording
import com.fatwabot.core.common.HapticsProviding
import com.fatwabot.core.common.NoopActivityEventRecording
import com.fatwabot.core.content.AzkarCategory
import com.fatwabot.core.content.AzkarItem
import com.fatwabot.core.content.ContentService
import dagger.hilt.android.lifecycle.HiltViewModel
import java.time.Instant
import java.time.ZoneId
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.datetime.Clock

/**
 * Session state machine for the Azkar reading experience — mirror of iOS
 * AzkarViewModel (docs/features/azkar.md). Category/item loading from
 * ContentKit is a thin synchronous wrapper; the session logic itself is
 * unit-testable with hand-built fixtures.
 */
@HiltViewModel
class AzkarViewModel @Inject constructor(
    private val contentService: ContentService?,
    private val haptics: HapticsProviding,
    private val store: AzkarStoring,
    private val clock: Clock,
    private val activityEvents: ActivityEventRecording = NoopActivityEventRecording(),
) : ViewModel() {

    data class UiState(
        val categories: List<AzkarCategory> = emptyList(),
        val hasLoadedCategories: Boolean = false,
        val items: List<AzkarItem> = emptyList(),
        val categoryId: String? = null,
        val currentItemIndex: Int = 0,
        val currentItemCount: Int = 0,
        val isSessionComplete: Boolean = false,
        val completedCategoryIdsToday: Set<String> = emptySet(),
    ) {
        val currentItem: AzkarItem?
            get() = items.getOrNull(currentItemIndex)

        val progress: Double
            get() = if (items.isEmpty()) 0.0 else currentItemIndex.toDouble() / items.size
    }

    private val _state = MutableStateFlow(
        UiState(
            completedCategoryIdsToday = store.loadCompletions()
                .filter { isSameDay(it.completedAtEpochSeconds, nowEpochSeconds()) }
                .map { it.categoryId }
                .toSet(),
        ),
    )
    val state: StateFlow<UiState> = _state.asStateFlow()

    fun loadCategories(locale: String) {
        val categories = contentService?.azkar(locale)?.categories.orEmpty()
        _state.update { it.copy(categories = categories, hasLoadedCategories = true) }
    }

    fun isCompletedToday(categoryId: String): Boolean = _state.value.completedCategoryIdsToday.contains(categoryId)

    /** Resumes from a persisted same-day position for the same category if one exists. */
    fun startSession(categoryId: String, items: List<AzkarItem>) {
        val persisted = store.loadSession()
        val canResume = persisted != null &&
            persisted.categoryId == categoryId &&
            isSameDay(persisted.lastTouchedAtEpochSeconds, nowEpochSeconds()) &&
            persisted.currentItemIndex < items.size

        _state.update {
            it.copy(
                categoryId = categoryId,
                items = items,
                isSessionComplete = false,
                currentItemIndex = if (canResume) persisted!!.currentItemIndex else 0,
                currentItemCount = if (canResume) persisted!!.currentItemCount else 0,
            )
        }
        if (!canResume) persistState()
    }

    /** Auto-advances at exactly the item's repeatCount (never N+1); a no-op once
     * complete, making completion idempotent. */
    fun tick() {
        val current = _state.value
        if (current.isSessionComplete) return
        val item = current.currentItem ?: return
        val newCount = current.currentItemCount + 1
        if (newCount >= item.repeatCount) {
            haptics.targetReached()
            advance()
        } else {
            haptics.tick()
            _state.update { it.copy(currentItemCount = newCount) }
            persistState()
        }
    }

    private fun advance() {
        val current = _state.value
        val newIndex = current.currentItemIndex + 1
        _state.update { it.copy(currentItemIndex = newIndex, currentItemCount = 0) }
        if (newIndex >= current.items.size) {
            completeSession()
        } else {
            persistState()
        }
    }

    private fun completeSession() {
        val categoryId = _state.value.categoryId ?: return
        store.saveSession(null)
        store.recordCompletion(AzkarCompletionRecord(categoryId, nowEpochSeconds()))
        _state.update {
            it.copy(isSessionComplete = true, completedCategoryIdsToday = it.completedCategoryIdsToday + categoryId)
        }
        activityEvents.record(eventType = "azkar_completed")
    }

    private fun persistState() {
        val current = _state.value
        val categoryId = current.categoryId ?: return
        store.saveSession(
            AzkarSessionState(
                categoryId = categoryId,
                currentItemIndex = current.currentItemIndex,
                currentItemCount = current.currentItemCount,
                lastTouchedAtEpochSeconds = nowEpochSeconds(),
            ),
        )
    }

    private fun nowEpochSeconds(): Long = clock.now().epochSeconds

    private fun isSameDay(aEpochSeconds: Long, bEpochSeconds: Long): Boolean {
        val zone = ZoneId.systemDefault()
        val a = Instant.ofEpochSecond(aEpochSeconds).atZone(zone).toLocalDate()
        val b = Instant.ofEpochSecond(bEpochSeconds).atZone(zone).toLocalDate()
        return a == b
    }
}
