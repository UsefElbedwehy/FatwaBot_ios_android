package com.fatwabot.core.content

import com.fatwabot.core.common.DeepLink
import kotlinx.datetime.DateTimeUnit
import kotlinx.datetime.Instant
import kotlinx.datetime.TimeZone
import kotlinx.datetime.atStartOfDayIn
import kotlinx.datetime.plus
import kotlinx.datetime.toLocalDateTime
import kotlinx.serialization.Serializable

/**
 * A single scheduled azkar/hadith reminder — mirror of iOS `PlannedContentReminder`.
 */
data class PlannedContentReminder(
    val id: String,
    val kind: Kind,
    /** The azkar/hadith item being shown, so the app can attribute it. */
    val contentId: String,
    val fireEpochSeconds: Long,
    /** Notification-template key, resolved to localized text at registration time. */
    val titleKey: String,
    /** Already-truncated scripture text — content, not a template key. */
    val body: String,
) {
    enum class Kind(val key: String, val deepLink: DeepLink) {
        AZKAR("azkar", DeepLink.AZKAR),
        HADITH("hadith", DeepLink.HADITH),
    }

    val deepLink: DeepLink get() = kind.deepLink
}

/**
 * One candidate line of content, stripped down to what a notification needs.
 * The planner takes these rather than [AzkarItem]/[HadithEntry] so it stays a
 * pure function over plain data — the app layer decides which field (Arabic text
 * vs. translation) to feed in for the current locale.
 */
data class ContentSnippet(val id: String, val text: String)

/**
 * User-facing preferences for the daily azkar/hadith reminders — mirror of iOS
 * `ContentReminderPreferences`.
 */
@Serializable
data class ContentReminderPreferences(
    val enabled: Boolean = true,
    /**
     * How many reminders to spread across the day. Owner decision: default 2
     * (one azkar, one hadith), user-adjustable 0–5, where 0 means off.
     */
    val perDay: Int = DEFAULT_PER_DAY,
) {
    /**
     * The count the planner actually uses. The toggle and a count of 0 are two
     * routes to the same "off", and both have to be honoured — otherwise a user
     * who dragged the stepper to 0 keeps getting notifications.
     */
    val effectiveCount: Int get() = if (enabled) clamp(perDay) else 0

    companion object {
        const val COUNT_MIN = 0
        const val COUNT_MAX = 5
        const val DEFAULT_PER_DAY = 2

        fun clamp(count: Int): Int = count.coerceIn(COUNT_MIN, COUNT_MAX)
    }
}

/**
 * Pure builder for the rolling azkar/hadith reminder schedule — mirror of iOS
 * `ContentReminderPlanner`. No Android APIs, no clock reads; the caller supplies
 * `now`, the time zone and the content pool, so this is fully unit-testable,
 * exactly like [com.fatwabot.core.prayer.NotificationPlanner].
 *
 * ## Why the "randomness" is seeded
 * Re-planning happens on every app launch and every settings change. A real RNG
 * would hand out different times each pass, so the app would cancel the pending
 * alarm and re-register it somewhere else — the user would see duplicates, or
 * silently lose the day's reminder when the new time landed in the past. Every
 * time and every pick is therefore derived from `(calendar day, slot index)`
 * through splitmix64: same day, same schedule, however often the planner runs.
 */
object ContentReminderPlanner {
    /** iOS refuses to hold more than 64 pending local notifications. */
    const val IOS_PENDING_LIMIT = 64

    /**
     * What the prayer schedule already reserves — the value of
     * `NotificationPlanner.DEFAULT_BUDGET`. Restated here (rather than imported)
     * only because `:core:content` must not depend on `:core:prayer`; the app
     * layer passes the real constant into [remainingBudget], so there is a single
     * source of truth at runtime.
     */
    const val ASSUMED_PRAYER_RESERVE = 48

    /**
     * The 16 slots left once prayer notifications have taken theirs. Android's
     * AlarmManager has no hard cap, but the two platforms keep the same ceiling
     * so a user doesn't get a different number of reminders per device.
     */
    const val DEFAULT_BUDGET = IOS_PENDING_LIMIT - ASSUMED_PRAYER_RESERVE

    /** Waking hours only — owner decision: nobody gets woken at 03:00. */
    const val WINDOW_START_HOUR = 9
    const val WINDOW_END_HOUR = 21

    /**
     * Notification bodies get elided by the OS well before this; a long hadith is
     * truncated at a word boundary rather than shown as a wall of text.
     */
    const val BODY_CHARACTER_LIMIT = 120

    /**
     * How far ahead to lay out reminders. The budget usually bites first (16
     * slots is a bit over three days at 5/day); planning a week means a user who
     * doesn't open the app still gets reminders until the budget runs out.
     */
    const val DEFAULT_HORIZON_DAYS = 7

    /** Slots left for content once the prayer schedule has taken its reservation. */
    fun remainingBudget(prayerReserve: Int): Int =
        (IOS_PENDING_LIMIT - prayerReserve).coerceAtLeast(0)

    fun plan(
        azkar: List<ContentSnippet>,
        hadith: List<ContentSnippet>,
        preferences: ContentReminderPreferences,
        now: Instant,
        timeZone: TimeZone,
        horizonDays: Int = DEFAULT_HORIZON_DAYS,
        budget: Int = DEFAULT_BUDGET,
    ): List<PlannedContentReminder> {
        val count = preferences.effectiveCount
        // An empty pool yields an empty plan rather than a crash: on a fresh
        // install the seed content may not have been read off disk yet.
        if (count <= 0 || budget <= 0 || horizonDays <= 0) return emptyList()
        if (azkar.isEmpty() && hadith.isEmpty()) return emptyList()

        val windowMinutes = (WINDOW_END_HOUR - WINDOW_START_HOUR) * 60
        // One reminder per equal sub-window, so two can never collide and can
        // never bunch up at the same end of the day.
        val slotMinutes = windowMinutes / count
        if (slotMinutes <= 0) return emptyList()

        val planned = mutableListOf<PlannedContentReminder>()
        val nowSeconds = now.epochSeconds
        val today = now.toLocalDateTime(timeZone).date

        for (dayOffset in 0 until horizonDays) {
            val date = today.plus(dayOffset, DateTimeUnit.DAY)
            val dayStart = date.atStartOfDayIn(timeZone)
            val dayKey = (date.year * 10_000 + date.monthNumber * 100 + date.dayOfMonth).toULong()

            for (slot in 0 until count) {
                // The seed is the whole determinism story: day + slot in, a fixed
                // time and a fixed pick out.
                val seed = splitmix64(dayKey * 64uL + slot.toULong())

                val minuteInSlot = (seed % slotMinutes.toULong()).toInt()
                val minuteOfDay = WINDOW_START_HOUR * 60 + slot * slotMinutes + minuteInSlot
                // Added as calendar minutes so a DST jump shifts the reminder with
                // the wall clock instead of landing an hour outside the window.
                val fire = dayStart.plus(minuteOfDay, DateTimeUnit.MINUTE, timeZone)
                if (fire.epochSeconds <= nowSeconds) continue

                // Alternate azkar/hadith so the default of 2 is one of each, and
                // fall back to the other pool when one of them is empty.
                var kind = if (slot % 2 == 0) {
                    PlannedContentReminder.Kind.AZKAR
                } else {
                    PlannedContentReminder.Kind.HADITH
                }
                if (pool(kind, azkar, hadith).isEmpty()) {
                    kind = if (kind == PlannedContentReminder.Kind.AZKAR) {
                        PlannedContentReminder.Kind.HADITH
                    } else {
                        PlannedContentReminder.Kind.AZKAR
                    }
                }
                val candidates = pool(kind, azkar, hadith)
                if (candidates.isEmpty()) continue

                // Re-hashed so the item choice doesn't correlate with the minute.
                val pickSeed = splitmix64(seed xor 0xA0761D6478BD642FuL)
                val item = candidates[(pickSeed % candidates.size.toULong()).toInt()]

                planned += PlannedContentReminder(
                    id = "content-${kind.key}-$dayKey-$slot",
                    kind = kind,
                    contentId = item.id,
                    fireEpochSeconds = fire.epochSeconds,
                    titleKey = "notif.content.${kind.key}.title",
                    body = truncate(item.text),
                )
            }
        }

        return planned.sortedBy { it.fireEpochSeconds }.take(budget)
    }

    /**
     * Shortens to [limit] characters on a word boundary, so a hadith never gets
     * cut mid-word. Whitespace is collapsed first — the seed JSON carries
     * newlines that would otherwise eat most of the visible line.
     */
    fun truncate(text: String, limit: Int = BODY_CHARACTER_LIMIT): String {
        val words = text.split(Regex("\\s+")).filter { it.isNotEmpty() }
        val collapsed = words.joinToString(" ")
        if (collapsed.length <= limit) return collapsed

        // Leave room for the ellipsis so the result still fits inside `limit`.
        val kept = StringBuilder()
        for (word in words) {
            val candidateLength = if (kept.isEmpty()) word.length else kept.length + 1 + word.length
            if (candidateLength > limit - 1) break
            if (kept.isNotEmpty()) kept.append(' ')
            kept.append(word)
        }
        // A single word longer than the whole limit has no boundary to cut on.
        if (kept.isEmpty()) kept.append(collapsed.take(limit - 1))
        return "$kept…"
    }

    private fun pool(
        kind: PlannedContentReminder.Kind,
        azkar: List<ContentSnippet>,
        hadith: List<ContentSnippet>,
    ): List<ContentSnippet> =
        if (kind == PlannedContentReminder.Kind.AZKAR) azkar else hadith

    /**
     * splitmix64 — a small, fast, well-mixed integer hash. Written out rather
     * than using [kotlin.random.Random] or `hashCode()` because the schedule has
     * to be reproducible across process restarts, which is precisely the bug
     * this whole design exists to avoid. The iOS port uses identical constants,
     * so both platforms derive the same schedule.
     */
    internal fun splitmix64(value: ULong): ULong {
        var z = value + 0x9E3779B97F4A7C15uL
        z = (z xor (z shr 30)) * 0xBF58476D1CE4E5B9uL
        z = (z xor (z shr 27)) * 0x94D049BB133111EBuL
        return z xor (z shr 31)
    }
}
