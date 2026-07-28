package com.fatwabot.feature.awrad

/**
 * One scheduled "did you do it today?" reminder — one per active wird.
 * Mirror of iOS `PlannedWirdReminder`.
 */
data class PlannedWirdReminder(
    val id: String,
    val wirdId: String,
    /** Interpolated into the notification title, so the user knows *which* wird
     * they are answering for without opening the app. */
    val wirdName: String,
    val hour: Int,
    val minute: Int,
)

/**
 * User-facing preferences for the daily wird reminder.
 * Mirror of iOS `WirdReminderPreferences`.
 */
data class WirdReminderPreferences(
    val enabled: Boolean = true,
    /** Local wall-clock hour the reminder fires at. Owner decision: 20:00 — late
     * enough that "did you do it today?" is a fair question, early enough that
     * the user can still act on a "no". */
    val hour: Int = DEFAULT_HOUR,
    val minute: Int = DEFAULT_MINUTE,
) {
    companion object {
        const val DEFAULT_HOUR = 20
        const val DEFAULT_MINUTE = 0

        fun clampHour(value: Int): Int = value.coerceIn(0, 23)
        fun clampMinute(value: Int): Int = value.coerceIn(0, 59)
    }
}

/**
 * Pure builder for the daily wird reminder schedule — no platform APIs, no clock
 * reads, so it is identical in intent to the iOS port and fully unit-testable
 * (same contract as [com.fatwabot.core.content.ContentReminderPlanner]).
 *
 * ## Why one repeating reminder per wird rather than a rolling horizon
 * The product shape is "one notification per active wird, once a day", and the
 * text never changes (the wird's name). One daily alarm per wird, re-armed after
 * each firing, therefore costs one pending slot rather than one per day — which
 * matters because the notification budget is shared with the prayer schedule.
 */
object WirdReminderPlanner {
    /** Every alarm id starts with this, so clearing ours can't touch the prayer
     * or content schedules. */
    const val ID_PREFIX = "wird-reminder-"

    /**
     * Slots carved out of the content reminders' slice of the shared budget.
     * Applied unconditionally (like the prayer reserve) so that turning wird
     * reminders on can never push the total over the cap mid-session.
     */
    const val NOTIFICATION_RESERVE = 5

    fun plan(
        wirds: List<Wird>,
        preferences: WirdReminderPreferences,
        budget: Int = NOTIFICATION_RESERVE,
    ): List<PlannedWirdReminder> {
        if (!preferences.enabled || budget <= 0) return emptyList()
        // Archived wirds are excluded here as well as in the responder: a
        // reminder for something the user retired is pure noise.
        // Creation order, with the id as a tie-breaker so the truncation the
        // budget forces is stable across runs rather than dependent on file order.
        return wirds.filter { it.isActive }
            .sortedWith(compareBy({ it.createdAtEpochSeconds }, { it.id }))
            .take(budget)
            .map {
                PlannedWirdReminder(
                    id = ID_PREFIX + it.id,
                    wirdId = it.id,
                    wirdName = it.name,
                    hour = WirdReminderPreferences.clampHour(preferences.hour),
                    minute = WirdReminderPreferences.clampMinute(preferences.minute),
                )
            }
    }

    /**
     * What is left of a caller's notification budget once the wird reminders
     * have taken their reservation. Used by the content-reminder scheduler so
     * there is one subtraction, in one place.
     */
    fun budgetAfterReserve(budget: Int): Int = (budget - NOTIFICATION_RESERVE).coerceAtLeast(0)
}
