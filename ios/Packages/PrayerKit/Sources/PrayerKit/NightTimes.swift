import Foundation

/// The two night markers derived from a night's span: منتصف الليل and الثلث الأخير.
///
/// ## Why this is its own type
/// The last third was computed inline in `NotificationPlan` and is now also
/// displayed by the day-sheet widget. Two copies of the arithmetic would be two
/// definitions of a religious time that must agree — the widget saying 1:39 and
/// the notification firing at 1:47 is not a rounding difference to a user, it is
/// the app contradicting itself about when qiyam begins. One definition, one
/// place, both callers.
///
/// ## The definition
/// The night runs from **Maghrib to the following day's Fajr** — not to midnight
/// on the clock, and not from Isha. Midnight is its midpoint; the last third
/// begins two-thirds of the way through. This is the majority convention and the
/// one the notification planner already shipped, so it is preserved exactly
/// rather than re-derived.
public struct NightTimes: Equatable, Sendable {
    /// منتصف الليل — the midpoint of the night, not 00:00 clock time.
    public let midnight: Date
    /// الثلث الأخير — where the final third of the night begins.
    public let lastThird: Date

    public init(midnight: Date, lastThird: Date) {
        self.midnight = midnight
        self.lastThird = lastThird
    }

    /// Night markers for the span `maghrib ..< nextFajr`.
    ///
    /// Returns `nil` when the span is not a real night. At extreme latitudes the
    /// calculator can place Fajr before the preceding Maghrib, and a negative
    /// night length yields markers that run backwards through the evening — a
    /// wrong time presented with total confidence. Absent is the honest answer
    /// there, and every caller already has to handle "no next day" anyway.
    public static func between(maghrib: Date, nextFajr: Date) -> NightTimes? {
        guard nextFajr > maghrib else { return nil }
        let length = nextFajr.timeIntervalSince(maghrib)
        return NightTimes(
            midnight: maghrib.addingTimeInterval(length / 2.0),
            lastThird: maghrib.addingTimeInterval(length * 2.0 / 3.0)
        )
    }
}
