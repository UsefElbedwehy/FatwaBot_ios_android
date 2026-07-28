package com.fatwabot.feature.awrad

import com.fatwabot.core.common.ActivityEventRecording
import com.fatwabot.core.common.NoopActivityEventRecording
import java.time.ZoneId
import javax.inject.Inject
import kotlinx.datetime.Clock

/**
 * What a "yes, I did it" answer actually changed. Returned rather than logged so
 * the caller (and the tests) can assert on it.
 */
data class WirdCompletionOutcome(
    /** False when the id names a wird that no longer exists or has been archived. */
    val wirdFound: Boolean,
    /** True only when the answer actually moved today's count. */
    val ticked: Boolean,
    /** True only when *this* answer was the one that completed the day. */
    val dayCompleted: Boolean,
) {
    companion object {
        val UNKNOWN_WIRD = WirdCompletionOutcome(wirdFound = false, ticked = false, dayCompleted = false)
    }
}

/**
 * Applies a "yes, I completed this wird" answer straight to the store, with no
 * [AwradViewModel] in the picture.
 *
 * ## Why this type exists
 * The answer arrives from a notification action button, handled by a
 * BroadcastReceiver — the app is usually backgrounded or dead. There is no live
 * view model to mutate, so the mutation has to go through [WirdStoring] directly,
 * and because it is the *same* state the UI writes it has to reproduce the UI's
 * rules exactly rather than approximate them.
 *
 * ## The rule it must not break
 * A *day* is complete only when every active wird has reached its target
 * ([AwradViewModel.markDayComplete]). Writing a [WirdDayCompletionRecord] straight
 * from a notification would report days complete whose per-wird counts don't
 * support it, inflating `completedDaysCount` and the Journey streaks. So this
 * raises the answered wird's count to its target — exactly the state a user
 * reaches by tapping it in the UI — and then lets day completion fall out of the
 * same all-active-wirds check.
 *
 * ## Idempotency
 * The answer *sets* today's count to the target rather than incrementing: a
 * re-answer of a wird already at (or past) its target is caught by
 * `current < target` and short-circuits, so no progress is written and no
 * `wird_ticked` is recorded. A double-tap, a duplicate notification, or answering
 * after finishing in-app all collapse to a single effect. Day completion is
 * separately guarded by the one-record-per-`dateKey` check.
 */
class WirdCompletionResponder @Inject constructor(
    private val store: WirdStoring,
    private val activityEvents: ActivityEventRecording = NoopActivityEventRecording(),
    private val clock: Clock = Clock.System,
    private val zone: ZoneId = ZoneId.systemDefault(),
) {
    /**
     * Answers "yes" for one wird. A deleted or archived id is a no-op, not a
     * crash — a stale notification can outlive the wird it was scheduled for.
     */
    fun answerCompleted(wirdId: String): WirdCompletionOutcome {
        val wirds = store.loadWirds()
        val wird = wirds.firstOrNull { it.id == wirdId && it.isActive }
            ?: return WirdCompletionOutcome.UNKNOWN_WIRD

        val key = AwradViewModel.dateKey(clock.now().epochSeconds, zone)
        val progress = store.loadProgress()
        val index = progress.indexOfFirst { it.wirdId == wirdId && it.dateKey == key }
        val current = if (index >= 0) progress[index].count else 0

        var ticked = false
        var updated = progress
        if (current < wird.target) {
            updated = if (index >= 0) {
                progress.toMutableList().apply { this[index] = this[index].copy(count = wird.target) }
            } else {
                progress + WirdDailyProgress(wirdId, key, wird.target)
            }
            store.saveProgress(updated)
            ticked = true
            // The same single event the in-app path fires: `tick(amount)` records
            // one `wird_ticked` per call whatever the amount, so a one-shot jump to
            // target and a stepper drag are indistinguishable to gamification.
            activityEvents.record(eventType = "wird_ticked", metadata = mapOf("wird_id" to wirdId))
        }

        return WirdCompletionOutcome(
            wirdFound = true,
            ticked = ticked,
            dayCompleted = recordDayCompletionIfEarned(wirds, updated, key),
        )
    }

    /** Byte-for-byte the `markDayComplete` rule, read off the store instead of
     * off in-memory state. */
    private fun recordDayCompletionIfEarned(
        wirds: List<Wird>,
        progress: List<WirdDailyProgress>,
        key: String,
    ): Boolean {
        if (store.loadDayCompletions().any { it.dateKey == key }) return false
        val active = wirds.filter { it.isActive }
        val counts = progress.filter { it.dateKey == key }.associate { it.wirdId to it.count }
        if (active.isEmpty() || !active.all { (counts[it.id] ?: 0) >= it.target }) return false

        store.recordDayCompletion(WirdDayCompletionRecord(key, clock.now().epochSeconds))
        activityEvents.record(eventType = "wird_day_completed")
        return true
    }
}
