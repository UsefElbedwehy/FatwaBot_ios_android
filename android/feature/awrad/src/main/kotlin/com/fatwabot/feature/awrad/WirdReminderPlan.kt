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
        val active = wirds.filter { it.isActive }
        val userCreated = active.filter { !it.isFixed }
            .sortedWith(compareBy({ it.createdAtEpochSeconds }, { it.id }))
        // The four fixed slots come last in the budget queue on purpose: they are
        // on every board, so ordering them first would evict the reminders of the
        // wirds a user deliberately created. The total is still capped at
        // `budget`, exactly as before — what changed is who fills the slots.
        val fixed = active.filter { it.isFixed }
            .sortedWith(
                compareBy(
                    { FixedWirdSlot.forWirdId(it.id)?.sortOrder ?: Int.MAX_VALUE },
                    { it.id },
                ),
            )
        return (userCreated + fixed).take(budget).map { wird ->
            // A fixed slot is asked about while it is still actionable (see
            // `FixedWirdSlot.reminderHour`) rather than piling onto the user's
            // one configured time.
            val slotHour = if (wird.isFixed) FixedWirdSlot.forWirdId(wird.id)?.reminderHour else null
            PlannedWirdReminder(
                id = ID_PREFIX + wird.id,
                wirdId = wird.id,
                wirdName = wird.name,
                hour = if (slotHour != null) {
                    WirdReminderPreferences.clampHour(slotHour)
                } else {
                    WirdReminderPreferences.clampHour(preferences.hour)
                },
                minute = if (slotHour != null) 0 else WirdReminderPreferences.clampMinute(preferences.minute),
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
