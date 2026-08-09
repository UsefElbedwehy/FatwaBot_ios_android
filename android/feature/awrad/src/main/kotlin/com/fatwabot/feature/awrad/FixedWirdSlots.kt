package com.fatwabot.feature.awrad

/**
 * The four awrad every user has, on every install, forever (owner decision,
 * 2026-07). Mirror of iOS `FixedWirdSlot`. They sit on the board next to
 * whatever the user creates, can be ticked and retargeted like any other wird,
 * and cannot be archived or removed.
 *
 * The ids are stable literals rather than UUIDs precisely because they have to
 * be recognisable across launches and across the two platforms — seeding is
 * "add the ids that are missing", which is what makes it idempotent.
 */
enum class FixedWirdSlot(
    /** Stable, human-readable, identical on iOS and Android. */
    val wirdId: String,
    /** Fallback used by tests and by any caller with no string resolver. */
    val defaultName: String,
    /**
     * Vocabulary matched to the backend `wird_templates` seed so the stats
     * aggregation keeps working: `unit == "pages"` feeds the Qur'an-pages tile.
     */
    val type: String,
    val unit: String,
    /**
     * Deliberately small. A fixed slot the user never asked for must not be the
     * thing that makes the day uncompletable; anyone who wants more retargets it.
     */
    val defaultTarget: Int,
    /**
     * Hour this slot's daily reminder fires at, overriding the user's single
     * reminder time. `null` means "use the user's time".
     *
     * Without this, four always-present wirds would fire four notifications in
     * the same minute — and a "did you do أذكار الصباح?" nudge at 20:00 is asking
     * about a window that closed hours ago. Each slot is asked about when it is
     * still actionable; the user's own wirds keep the time they configured.
     */
    val reminderHour: Int?,
) {
    QIYAM_AL_LAYL("fixed-qiyam-al-layl", "قيام الليل", "qiyam", "rakaat", 2, 22),
    DAILY_QURAN("fixed-daily-quran", "ورد يومي من القرآن", "quran_reading", "pages", 1, null),
    MORNING_AZKAR("fixed-morning-azkar", "أذكار الصباح", "azkar", "times", 1, 8),
    EVENING_AZKAR("fixed-evening-azkar", "أذكار المساء", "azkar", "times", 1, 17),
    ;

    val frequency: String get() = "daily"

    /** Board / reminder order. */
    val sortOrder: Int get() = ordinal

    /**
     * The prayer this slot can be anchored to, when offering the "follow the
     * prayer instead of the clock" option. Mirror of iOS `anchorPrayer`.
     *
     * Only the two azkar slots have one: their windows are defined by a prayer
     * and move by over an hour across the year, so a fixed time chosen in summer
     * lands at the wrong end of the window in winter. قيام الليل follows the last
     * third of the night rather than a prayer, and the Qur'an wird has no
     * natural anchor at all.
     */
    val anchorPrayer: String?
        get() = when (this) {
            MORNING_AZKAR -> "fajr"
            EVENING_AZKAR -> "asr"
            QIYAM_AL_LAYL, DAILY_QURAN -> null
        }

    /** Default minutes after the anchor prayer. */
    val defaultAnchorOffsetMinutes: Int get() = 30

    companion object {
        fun forWirdId(wirdId: String): FixedWirdSlot? = entries.firstOrNull { it.wirdId == wirdId }
    }
}

object FixedWirdSlots {
    /**
     * Resolves a slot's display name. The app injects a `Context.getString`
     * lookup; the default keeps the module testable without resources.
     */
    fun interface NameResolver {
        fun name(slot: FixedWirdSlot): String
    }

    val defaultNames = NameResolver { it.defaultName }

    fun isFixed(wirdId: String): Boolean = FixedWirdSlot.forWirdId(wirdId) != null

    fun wird(
        slot: FixedWirdSlot,
        name: NameResolver = defaultNames,
        nowEpochSeconds: Long,
    ): Wird = Wird(
        id = slot.wirdId,
        name = name.name(slot),
        type = slot.type,
        target = slot.defaultTarget,
        unit = slot.unit,
        frequency = slot.frequency,
        createdAtEpochSeconds = nowEpochSeconds,
        isFixed = true,
    )

    /**
     * The seeding rule, as one pure function so both platforms and the tests
     * can agree on it.
     *
     * - Appends only the slots whose id is **missing**, in canonical order, so
     *   running it on every launch can never duplicate a slot or reset the
     *   target/name of one the user already has.
     * - Marks a record whose id matches a slot as fixed even when the stored
     *   `isFixed` is absent/false. Records written before this feature existed
     *   deserialize with `isFixed = false`; normalising here is the Kotlin
     *   equivalent of the fallback in iOS's hand-written `Wird` decoder, and it
     *   means nothing downstream has to remember to check the id as well.
     * - Clears `archivedAtEpochSeconds` on a fixed slot. That is a repair, not a
     *   resurrection: a fixed slot is never archivable in the first place, so a
     *   record carrying that flag came from a bug or a hand-edited file.
     */
    fun applied(
        wirds: List<Wird>,
        name: NameResolver = defaultNames,
        nowEpochSeconds: Long,
    ): List<Wird> {
        val result = wirds.map { wird ->
            if (!wird.isFixed && !isFixed(wird.id)) {
                wird
            } else {
                wird.copy(isFixed = true, archivedAtEpochSeconds = null)
            }
        }.toMutableList()
        val present = result.mapTo(mutableSetOf()) { it.id }
        for (slot in FixedWirdSlot.entries) {
            if (slot.wirdId !in present) result += wird(slot, name, nowEpochSeconds)
        }
        return result
    }
}

/**
 * [WirdStoring] decorator that guarantees the four fixed slots exist — for
 * everyone, not just fresh installs. Mirror of iOS `SeededWirdStore`.
 *
 * ## Why a decorator instead of a first-launch migration
 * Three separate paths read the wird list: the board's view model, the
 * notification-action [WirdCompletionResponder], and the reminder scheduler.
 * A migration hung off app start would leave whichever of those ran first on a
 * cold launch looking at an unseeded list. Doing it on read means every reader
 * sees the same board, and the write only happens when something was actually
 * missing — so repeated launches are a no-op, not a rewrite.
 */
class SeededWirdStore(
    private val base: WirdStoring,
    private val name: FixedWirdSlots.NameResolver = FixedWirdSlots.defaultNames,
    private val now: () -> Long,
) : WirdStoring {

    /**
     * The four fixed slots, and only those.
     *
     * Client decision (2026-08-09): أثرك is the four everyone has, not a list a
     * user curates. The board previously mixed them with user-created wirds and
     * marked them with an "أساسي" badge; the badge is gone because with only
     * four there is nothing left to distinguish.
     *
     * Filtered here rather than in the board, because the board is not the only
     * consumer — the reminder planner reads the same store, and filtering only
     * the UI would have kept firing "did you complete it?" for wirds the user
     * could no longer see.
     *
     * Existing user wirds are **not deleted from disk**, only unreturned.
     */
    override fun loadWirds(): List<Wird> = allWirds().filter { it.isFixed }

    /**
     * Everything on disk. Seeding must see the full board, or it would re-add
     * the four slots on every read.
     */
    private fun allWirds(): List<Wird> {
        val existing = base.loadWirds()
        val seeded = FixedWirdSlots.applied(existing, name, now())
        if (seeded == existing) return existing
        // Only reached the first time the four slots land on an existing board.
        grantTodayIfAlreadyEarned(existing)
        base.saveWirds(seeded)
        return seeded
    }

    /**
     * Also enforced on write, so a caller that drops a fixed slot from the list
     * (or archives one) cannot persist that.
     */
    /**
     * Merges rather than replaces.
     *
     * [loadWirds] now returns only the four fixed slots, and callers do
     * load → modify → save. A plain replace would write back a four-item list
     * and **erase every user-created wird from disk** — turning "hidden" into
     * "destroyed" the first time someone tapped a counter, with no warning and
     * no way back. Anything on disk the caller never saw is carried through.
     */
    override fun saveWirds(wirds: List<Wird>) {
        val incoming = wirds.map { it.id }.toSet()
        val unseen = base.loadWirds().filterNot { it.id in incoming }
        base.saveWirds(FixedWirdSlots.applied(wirds + unseen, name, now()))
    }

    override fun loadProgress(): List<WirdDailyProgress> = base.loadProgress()
    override fun saveProgress(progress: List<WirdDailyProgress>) = base.saveProgress(progress)
    override fun loadDayCompletions(): List<WirdDayCompletionRecord> = base.loadDayCompletions()
    override fun recordDayCompletion(record: WirdDayCompletionRecord) = base.recordDayCompletion(record)

    /**
     * Day completion is all-or-nothing over the *active* wirds, so seeding four
     * more of them mid-day would retroactively un-earn a day a user had already
     * finished under the old board. Their history ([WirdDayCompletionRecord]s)
     * is never recomputed, so past days and streaks are safe — but today's,
     * which had been earned and not yet banked, would quietly vanish.
     *
     * So at the moment of seeding: if the pre-seed board was already fully done
     * today, bank that day before the new slots take effect. From tomorrow the
     * four count like everything else — which is the intended, harder rule.
     */
    private fun grantTodayIfAlreadyEarned(preSeed: List<Wird>) {
        val active = preSeed.filter { it.isActive }
        if (active.isEmpty()) return // fresh install: nothing was earned
        val key = AwradViewModel.dateKey(now())
        if (base.loadDayCompletions().any { it.dateKey == key }) return
        val counts = base.loadProgress()
            .filter { it.dateKey == key }
            .associate { it.wirdId to it.count }
        if (!active.all { (counts[it.id] ?: 0) >= it.target }) return
        base.recordDayCompletion(WirdDayCompletionRecord(key, now()))
    }
}
