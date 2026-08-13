package com.fatwabot.feature.awrad

/**
 * The four awrad offered as a one-tap starting board (client decision,
 * 2026-08-12, reversing the 2026-08-09 "seeded for everyone, forever"
 * decision). Mirror of iOS `FixedWirdSlot`. Nothing is seeded automatically —
 * a user adds them via "أضف ورد اليوم" — and once on the board they are
 * ordinary wirds: tickable, retargetable, and deletable like any wird the
 * user creates themselves.
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
     * Refreshes the display name (and repairs `isFixed`) of every fixed-slot
     * record to the *current* resolver's value. Unlike [applied], this
     * neither adds a missing slot nor reactivates an archived one, so it is
     * safe to run passively on every load — a fixed slot's name is not
     * something a user ever chose (retargeting is the only edit these slots
     * offer), so unlike a template wird's frozen name, it has no reason to
     * stay frozen under whatever language happened to be active the first
     * time it was seeded.
     */
    fun normalized(wirds: List<Wird>, name: NameResolver = defaultNames): List<Wird> =
        wirds.map { wird ->
            val slot = FixedWirdSlot.forWirdId(wird.id) ?: return@map wird
            wird.copy(isFixed = true, name = name.name(slot))
        }

    /**
     * The seeding rule, invoked once when the user taps "أضف ورد اليوم" — not on
     * every launch anymore, so both platforms and the tests can still agree on
     * what one tap does.
     *
     * - Appends a fresh instance only for a slot whose id is **entirely
     *   missing**, in canonical order, so a repeat tap can never duplicate a
     *   slot or reset the target of one the user already has.
     * - Un-archives a fixed slot that is present but was previously deleted.
     *   That is exactly what re-adding it means: the same slot, its history
     *   under that id intact, active again — not a fresh duplicate record.
     */
    fun applied(
        wirds: List<Wird>,
        name: NameResolver = defaultNames,
        nowEpochSeconds: Long,
    ): List<Wird> {
        val result = normalized(wirds, name).map { wird ->
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
