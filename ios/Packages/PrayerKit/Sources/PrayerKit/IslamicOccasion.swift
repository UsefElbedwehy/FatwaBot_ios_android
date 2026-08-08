import Foundation

/// Days remaining until Ramadan and the two Eids.
///
/// ## What this number is, and is not
/// It is arithmetic over the **Umm al-Qura** calendar, the same calendar the
/// rest of the app's Hijri dates come from. That is a computed calendar, and the
/// actual start of Ramadan is determined by moon sighting in each country — so
/// this can legitimately differ from the announced date by a day.
///
/// The widget presents it as a countdown, not as a ruling, which is why "٣ أيام"
/// is acceptable where "Ramadan begins on the 8th" would not be. If a precise
/// date is ever surfaced, it needs a sighting source rather than this file.
///
/// ## Why the target is the *next* occurrence rather than this year's
/// Asking for "days until Ramadan" on 15 Ramadan should not answer −14. Each
/// occasion resolves to the next time that Hijri day comes round, so the number
/// is always forward-looking; during the occasion itself the countdown is to
/// next year's, which is the honest reading of "how long until Ramadan".
public enum IslamicOccasion: String, CaseIterable, Sendable {
    case ramadan
    case eidAlFitr
    case eidAlAdha

    /// (Hijri month, Hijri day) this occasion begins on.
    var target: (month: Int, day: Int) {
        switch self {
        case .ramadan: (9, 1)
        case .eidAlFitr: (10, 1)   // 1 Shawwal
        case .eidAlAdha: (12, 10)  // 10 Dhu al-Hijja
        }
    }

    public var titleKey: String {
        switch self {
        case .ramadan: "occasion.ramadan"
        case .eidAlFitr: "occasion.eid_al_fitr"
        case .eidAlAdha: "occasion.eid_al_adha"
        }
    }
}

public struct IslamicOccasionCountdown: Equatable, Sendable {
    public let occasion: IslamicOccasion
    /// Whole days from `date` to the occasion. Zero means it begins today.
    public let daysRemaining: Int
    /// The Gregorian day the occasion falls on, per Umm al-Qura.
    public let gregorianDate: Date

    public init(occasion: IslamicOccasion, daysRemaining: Int, gregorianDate: Date) {
        self.occasion = occasion
        self.daysRemaining = daysRemaining
        self.gregorianDate = gregorianDate
    }
}

public enum IslamicOccasionCalculator {
    /// Countdown to `occasion` from `date`, or nil if the calendar cannot
    /// resolve it (never expected, but preferable to a fabricated number).
    ///
    /// `offsetDays` is the user's Hijri adjustment, applied the same way
    /// `HijriDate` applies it so the countdown and the displayed Hijri date
    /// cannot disagree — a widget reading "25 صفر" beside a Ramadan countdown
    /// computed off an unadjusted calendar would be visibly inconsistent.
    public static func countdown(
        to occasion: IslamicOccasion,
        from date: Date = Date(),
        offsetDays: Int = 0
    ) -> IslamicOccasionCountdown? {
        var hijri = Calendar(identifier: .islamicUmmAlQura)
        hijri.timeZone = TimeZone.current
        let gregorian = Calendar.current

        let adjusted = gregorian.date(byAdding: .day, value: offsetDays, to: date) ?? date
        let today = gregorian.startOfDay(for: adjusted)

        // `nextDate` searches strictly after the given instant, so starting the
        // search a moment before today keeps an occasion that begins *today*
        // reporting 0 rather than skipping a whole year ahead.
        let searchFrom = today.addingTimeInterval(-1)
        var components = DateComponents()
        components.month = occasion.target.month
        components.day = occasion.target.day

        guard let next = hijri.nextDate(
            after: searchFrom, matching: components,
            matchingPolicy: .nextTime, direction: .forward
        ) else { return nil }

        let target = gregorian.startOfDay(for: next)
        let days = gregorian.dateComponents([.day], from: today, to: target).day ?? 0
        // The occasion's real Gregorian date is the adjusted one shifted back,
        // so a user with a +1 offset sees the date their calendar shows.
        let display = gregorian.date(byAdding: .day, value: -offsetDays, to: target) ?? target
        return IslamicOccasionCountdown(
            occasion: occasion, daysRemaining: max(0, days), gregorianDate: display
        )
    }

    /// All three, in calendar order.
    public static func all(
        from date: Date = Date(), offsetDays: Int = 0
    ) -> [IslamicOccasionCountdown] {
        IslamicOccasion.allCases
            .compactMap { countdown(to: $0, from: date, offsetDays: offsetDays) }
            .sorted { $0.daysRemaining < $1.daysRemaining }
    }
}
