import Foundation

/// The four awrad offered as a one-tap starting board (client decision,
/// 2026-08-12, reversing the 2026-08-09 "seeded for everyone, forever"
/// decision): قيام الليل، ورد يومي من القرآن، أذكار الصباح، أذكار المساء. Nothing
/// is seeded automatically — a user adds them via "أضف ورد اليوم" — and once on
/// the board they are ordinary wirds: tickable, retargetable, and deletable
/// like any wird the user creates themselves.
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

    /// Refreshes the display name of every fixed-slot record to the
    /// *current* resolver's value. Unlike `applied`, this neither adds a
    /// missing slot nor reactivates an archived one, so it is safe to run
    /// passively on every load — a fixed slot's name is not something a user
    /// ever chose (retargeting is the only edit these slots offer), so unlike
    /// a template wird's frozen name, it has no reason to stay frozen under
    /// whatever language happened to be active the first time it was seeded.
    public static func normalized(_ wirds: [Wird], name: NameResolver = defaultNames) -> [Wird] {
        wirds.map { wird in
            guard let slot = FixedWirdSlot(wirdId: wird.id) else { return wird }
            var updated = wird
            updated.name = name(slot)
            return updated
        }
    }

    /// The seeding rule, invoked once when the user taps "أضف ورد اليوم" — not on
    /// every launch anymore, so both platforms and the tests can still agree on
    /// what one tap does.
    ///
    /// - Appends a fresh instance only for a slot whose id is **entirely
    ///   missing**, in canonical order, so a repeat tap can never duplicate a
    ///   slot or reset the target of one the user already has.
    /// - Un-archives a fixed slot that is present but was previously deleted.
    ///   That is exactly what re-adding it means: the same slot, its history
    ///   under that id intact, active again — not a fresh duplicate record.
    public static func applied(to wirds: [Wird], name: NameResolver = defaultNames, now: Date) -> [Wird] {
        var result = normalized(wirds, name: name).map { wird -> Wird in
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
