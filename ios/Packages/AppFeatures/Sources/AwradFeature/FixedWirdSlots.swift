import Foundation

/// The four awrad every user has, on every install, forever (owner decision,
/// 2026-07). They sit on the board next to whatever the user creates, can be
/// ticked and retargeted like any other wird, and cannot be archived or removed.
///
/// The ids are stable literals rather than UUIDs precisely because they have to
/// be recognisable across launches and across the two platforms — seeding is
/// "add the ids that are missing", which is what makes it idempotent.
public enum FixedWirdSlot: String, CaseIterable, Sendable {
    case qiyamAlLayl
    case dailyQuran
    case morningAzkar
    case eveningAzkar

    /// Stable, human-readable, identical on iOS and Android.
    public var wirdId: String {
        switch self {
        case .qiyamAlLayl: "fixed-qiyam-al-layl"
        case .dailyQuran: "fixed-daily-quran"
        case .morningAzkar: "fixed-morning-azkar"
        case .eveningAzkar: "fixed-evening-azkar"
        }
    }

    /// Localization key the app layer resolves. The *resolved* string is what
    /// gets persisted into `Wird.name` at seeding time — same as a template-created
    /// wird, whose name is likewise frozen in the locale it was created in.
    public var nameKey: String {
        switch self {
        case .qiyamAlLayl: "awrad.fixed.qiyam_al_layl"
        case .dailyQuran: "awrad.fixed.daily_quran"
        case .morningAzkar: "awrad.fixed.morning_azkar"
        case .eveningAzkar: "awrad.fixed.evening_azkar"
        }
    }

    /// Fallback used by tests and by any caller that has no string resolver.
    public var defaultName: String {
        switch self {
        case .qiyamAlLayl: "قيام الليل"
        case .dailyQuran: "ورد يومي من القرآن"
        case .morningAzkar: "أذكار الصباح"
        case .eveningAzkar: "أذكار المساء"
        }
    }

    /// Vocabulary matched to the backend `wird_templates` seed so the stats
    /// aggregation keeps working: `unit == "pages"` feeds the Qur'an-pages tile.
    public var type: String {
        switch self {
        case .qiyamAlLayl: "qiyam"
        case .dailyQuran: "quran_reading"
        case .morningAzkar, .eveningAzkar: "azkar"
        }
    }

    public var unit: String {
        switch self {
        case .qiyamAlLayl: "rakaat"
        case .dailyQuran: "pages"
        case .morningAzkar, .eveningAzkar: "times"
        }
    }

    /// Deliberately small. A fixed slot the user never asked for must not be the
    /// thing that makes the day uncompletable; anyone who wants more retargets it.
    public var defaultTarget: Int {
        switch self {
        case .qiyamAlLayl: 2
        case .dailyQuran: 1
        case .morningAzkar, .eveningAzkar: 1
        }
    }

    public var frequency: String { "daily" }

    /// Hour this slot's daily reminder fires at, overriding the user's single
    /// reminder time. `nil` means "use the user's time".
    ///
    /// Without this, four always-present wirds would fire four notifications in
    /// the same minute — and a "did you do أذكار الصباح?" nudge at 20:00 is asking
    /// about a window that closed hours ago. Each slot is asked about when it is
    /// still actionable; the user's own wirds keep the time they configured.
    public var reminderHour: Int? {
        switch self {
        case .qiyamAlLayl: 22
        case .dailyQuran: nil
        case .morningAzkar: 8
        case .eveningAzkar: 17
        }
    }

    /// The prayer this slot can be anchored to, when offering the
    /// "follow the prayer instead of the clock" option.
    ///
    /// Only the two azkar slots have one. أذكار الصباح and أذكار المساء are tied
    /// to a prayer by definition, and their windows move by over an hour across
    /// the year — a fixed time chosen in summer lands at the wrong end of the
    /// window in winter. قيام الليل is anchored to the last third of the night
    /// rather than a prayer, and the Qur'an wird has no natural anchor at all.
    public var anchorPrayer: String? {
        switch self {
        case .morningAzkar: "fajr"
        case .eveningAzkar: "asr"
        case .qiyamAlLayl, .dailyQuran: nil
        }
    }

    /// Default minutes after the anchor prayer. Enough that the prayer itself is
    /// done before the app asks about the adhkar that follow it.
    public var defaultAnchorOffsetMinutes: Int { 30 }

    /// Board / reminder order.
    public var sortOrder: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    public init?(wirdId: String) {
        guard let match = Self.allCases.first(where: { $0.wirdId == wirdId }) else { return nil }
        self = match
    }
}

public enum FixedWirdSlots {
    /// Resolves a slot's display name. The app injects `NSLocalizedString`; the
    /// default keeps the package testable without a bundle.
    public typealias NameResolver = @Sendable (FixedWirdSlot) -> String

    public static let defaultNames: NameResolver = { $0.defaultName }

    public static func isFixed(wirdId: String) -> Bool { FixedWirdSlot(wirdId: wirdId) != nil }

    public static func wird(for slot: FixedWirdSlot, name: NameResolver = defaultNames, now: Date) -> Wird {
        Wird(
            id: slot.wirdId,
            name: name(slot),
            type: slot.type,
            target: slot.defaultTarget,
            unit: slot.unit,
            frequency: slot.frequency,
            createdAt: now,
            isFixed: true
        )
    }

    /// The seeding rule, as one pure function so both platforms and the tests
    /// can agree on it.
    ///
    /// - Appends only the slots whose id is **missing**, in canonical order, so
    ///   running it on every launch can never duplicate a slot or reset the
    ///   target/name of one the user already has.
    /// - Clears `archivedAt` on a fixed slot. That is a repair, not a
    ///   resurrection: a fixed slot is never archivable in the first place, so a
    ///   record carrying that flag came from a bug or a hand-edited file.
    public static func applied(to wirds: [Wird], name: NameResolver = defaultNames, now: Date) -> [Wird] {
        var result = wirds.map { wird -> Wird in
            guard wird.isFixed || isFixed(wirdId: wird.id), wird.archivedAt != nil else { return wird }
            var repaired = wird
            repaired.archivedAt = nil
            return repaired
        }
        let present = Set(result.map(\.id))
        for slot in FixedWirdSlot.allCases where !present.contains(slot.wirdId) {
            result.append(wird(for: slot, name: name, now: now))
        }
        return result
    }
}

/// `WirdStoring` decorator that guarantees the four fixed slots exist — for
/// everyone, not just fresh installs.
///
/// ## Why a decorator instead of a first-launch migration
/// Three separate paths read the wird list: the board's view model, the
/// notification-action `WirdCompletionResponder`, and the reminder scheduler.
/// A migration hung off app start would leave whichever of those ran first on a
/// cold launch looking at an unseeded list. Doing it on read means every reader
/// sees the same board, and the write only happens when something was actually
/// missing — so repeated launches are a no-op, not a rewrite.
public struct SeededWirdStore: WirdStoring {
    private let base: WirdStoring
    private let name: FixedWirdSlots.NameResolver
    private let now: @Sendable () -> Date
    private let calendar: Calendar

    public init(
        wrapping base: WirdStoring,
        name: @escaping FixedWirdSlots.NameResolver = FixedWirdSlots.defaultNames,
        now: @escaping @Sendable () -> Date = { Date() },
        calendar: Calendar = .current
    ) {
        self.base = base
        self.name = name
        self.now = now
        self.calendar = calendar
    }

    public func loadWirds() -> [Wird] {
        let existing = base.loadWirds()
        let seeded = FixedWirdSlots.applied(to: existing, name: name, now: now())
        guard seeded != existing else { return existing }
        // Only reached the first time the four slots land on an existing board.
        grantTodayIfAlreadyEarned(preSeed: existing)
        base.saveWirds(seeded)
        return seeded
    }

    /// Also enforced on write, so a caller that drops a fixed slot from the list
    /// (or archives one) cannot persist that.
    public func saveWirds(_ wirds: [Wird]) {
        base.saveWirds(FixedWirdSlots.applied(to: wirds, name: name, now: now()))
    }

    public func loadProgress() -> [WirdDailyProgress] { base.loadProgress() }
    public func saveProgress(_ progress: [WirdDailyProgress]) { base.saveProgress(progress) }
    public func loadDayCompletions() -> [WirdDayCompletionRecord] { base.loadDayCompletions() }
    public func recordDayCompletion(_ record: WirdDayCompletionRecord) { base.recordDayCompletion(record) }

    /// Day completion is all-or-nothing over the *active* wirds, so seeding four
    /// more of them mid-day would retroactively un-earn a day a user had already
    /// finished under the old board. Their history (`WirdDayCompletionRecord`s)
    /// is never recomputed, so past days and streaks are safe — but today's,
    /// which had been earned and not yet banked, would quietly vanish.
    ///
    /// So at the moment of seeding: if the pre-seed board was already fully done
    /// today, bank that day before the new slots take effect. From tomorrow the
    /// four count like everything else — which is the intended, harder rule.
    private func grantTodayIfAlreadyEarned(preSeed: [Wird]) {
        let active = preSeed.filter(\.isActive)
        guard !active.isEmpty else { return } // fresh install: nothing was earned
        let key = AwradViewModel.dateKey(for: now(), calendar: calendar)
        guard !base.loadDayCompletions().contains(where: { $0.dateKey == key }) else { return }
        let counts = Dictionary(
            base.loadProgress().filter { $0.dateKey == key }.map { ($0.wirdId, $0.count) },
            uniquingKeysWith: { first, _ in first }
        )
        guard active.allSatisfy({ (counts[$0.id] ?? 0) >= $0.target }) else { return }
        base.recordDayCompletion(WirdDayCompletionRecord(dateKey: key, completedAt: now()))
    }
}
