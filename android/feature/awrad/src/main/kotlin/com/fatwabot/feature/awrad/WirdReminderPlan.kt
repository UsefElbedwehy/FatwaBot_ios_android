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

/** A wall-clock time of day for one wird's reminder. Mirror of iOS `WirdReminderTime`. */
data class WirdReminderTime(val hour: Int, val minute: Int) {
    companion object {
        /** Clamping factory — out-of-range input is corrected, never rejected. */
        fun of(hour: Int, minute: Int): WirdReminderTime = WirdReminderTime(
            WirdReminderPreferences.clampHour(hour),
            WirdReminderPreferences.clampMinute(minute),
        )
    }
}

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
    /**
     * Per-wird overrides, keyed by wird id.
     *
     * Client request: "يفضل اختيار لكل ورد وقت محدد". Before this there was one
     * time for everything the user created, and the four fixed slots used
     * hardcoded hours nobody could change. A missing entry means "no override",
     * so an untouched install behaves exactly as it did — and a stored blob
     * written before this field existed still deserializes.
     */
    val timesByWird: Map<String, WirdReminderTime> = emptyMap(),
) {
    /**
     * The time a wird's reminder should fire.
     *
     * Resolution order, each step for a reason:
     *  1. the user's own override — an explicit choice always wins;
     *  2. the slot's built-in hour, so أذكار الصباح is still asked about in the
     *     morning rather than at the generic evening time;
     *  3. the global time, which is what a user-created wird has always used.
     */
    fun timeFor(wirdId: String, slotDefaultHour: Int?): WirdReminderTime =
        timesByWird[wirdId]
            ?: slotDefaultHour?.let { WirdReminderTime.of(it, 0) }
            // Clamped, not raw: these values come straight from persisted user
            // input, and the previous code clamped at every use site. An
            // existing planner test caught the omission.
            ?: WirdReminderTime.of(hour, minute)

    /** Copy with one wird's time set. */
    fun withTime(wirdId: String, time: WirdReminderTime): WirdReminderPreferences =
        copy(timesByWird = timesByWird + (wirdId to time))

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
                hour = preferences.timeFor(wird.id, slotHour).hour,
                minute = preferences.timeFor(wird.id, slotHour).minute,
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
