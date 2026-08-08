import Foundation

/// The Hijri week strip shown in the الصلاة والتقويم widget.
///
/// ## The strip can span a Hijri month boundary, and the header names only today's
/// Hijri months change on a different boundary from Gregorian weeks, so a week
/// containing a rollover genuinely reads `29 30 1 2`. The header is derived from
/// **today's** Hijri date, which means for part of such a week the header names a
/// month that some of the trailing columns are no longer in.
///
/// That is deliberate rather than unhandled: the header answers "what is the date
/// today", which is what a reader glancing at the widget wants, and every other
/// Hijri date in the app agrees with it. Naming both months would need twice the
/// width this row has. Verified on device — the seam renders as `30 1` under the
/// outgoing month's name.
///
/// If that is ever considered wrong, the fix is a per-column month, not a
/// different week anchor.
public struct HijriWeek: Equatable, Sendable {
    public struct Day: Equatable, Sendable, Identifiable {
        /// Hijri day-of-month.
        public let number: Int
        /// Short weekday label, already localized (أح، إث، …).
        public let weekdayLabel: String
        public let isToday: Bool

        public var id: Int { number }

        public init(number: Int, weekdayLabel: String, isToday: Bool) {
            self.number = number
            self.weekdayLabel = weekdayLabel
            self.isToday = isToday
        }
    }

    public let monthName: String
    public let year: Int
    public let days: [Day]

    public init(monthName: String, year: Int, days: [Day]) {
        self.monthName = monthName
        self.year = year
        self.days = days
    }

    /// The seven days of the week containing `date`.
    ///
    /// `offsetDays` matches the user's Hijri adjustment, so the strip and every
    /// other Hijri date in the app move together.
    public static func containing(
        _ date: Date,
        offsetDays: Int = 0,
        locale: Locale = Locale(identifier: "ar")
    ) -> HijriWeek {
        var hijri = Calendar(identifier: .islamicUmmAlQura)
        hijri.locale = locale
        let gregorian = Calendar.current

        let adjusted = gregorian.date(byAdding: .day, value: offsetDays, to: date) ?? date
        let today = gregorian.startOfDay(for: adjusted)

        // Anchor on the week's start in the *display* calendar so the columns
        // line up under their weekday labels the way a reader expects.
        let weekday = gregorian.component(.weekday, from: today)
        let start = gregorian.date(
            byAdding: .day, value: -(weekday - gregorian.firstWeekday + 7) % 7, to: today
        ) ?? today

        let symbols = shortWeekdaySymbols(locale: locale, firstWeekday: gregorian.firstWeekday)
        let days = (0..<7).compactMap { offset -> Day? in
            guard let day = gregorian.date(byAdding: .day, value: offset, to: start) else { return nil }
            return Day(
                number: hijri.component(.day, from: day),
                weekdayLabel: symbols[offset],
                isToday: gregorian.isDate(day, inSameDayAs: today)
            )
        }

        let hijriToday = HijriDate(from: date, offsetDays: offsetDays, locale: locale)
        return HijriWeek(monthName: hijriToday.monthName, year: hijriToday.year, days: days)
    }

    private static func shortWeekdaySymbols(locale: Locale, firstWeekday: Int) -> [String] {
        let formatter = DateFormatter()
        formatter.locale = locale
        let symbols = formatter.veryShortWeekdaySymbols ?? ["S", "M", "T", "W", "T", "F", "S"]
        // Rotated to the locale's first weekday — otherwise the labels are
        // correct but sit above the wrong columns, which is worse than useless.
        return (0..<7).map { symbols[(firstWeekday - 1 + $0) % 7] }
    }
}
