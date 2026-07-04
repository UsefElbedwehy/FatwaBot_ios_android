import Adhan
import Foundation

/// User-facing prayer names. `sunrise` is a displayed time but not a prayer.
public enum PrayerName: String, CaseIterable, Codable, Sendable {
    case fajr, sunrise, dhuhr, asr, maghrib, isha

    public var isPrayer: Bool { self != .sunrise }
}

/// Resolved calculation settings (docs/features/prayer.md). Defaults flow:
/// user override → /v1/config/prayer-defaults(country) → bundled fallback.
public struct PrayerSettings: Codable, Equatable, Sendable {
    public var method: String
    public var madhab: String
    /// nil = automatic: no rule below the high-latitude threshold, recommended
    /// rule above it (spike finding: never rely on library defaults ≥48°).
    public var highLatitudeRule: String?
    /// Manual per-prayer adjustments in minutes (±30 enforced here).
    public var adjustments: [PrayerName: Int]
    public var hijriOffsetDays: Int

    public static let highLatitudeThreshold = 48.0

    public init(
        method: String = "mwl",
        madhab: String = "shafi",
        highLatitudeRule: String? = nil,
        adjustments: [PrayerName: Int] = [:],
        hijriOffsetDays: Int = 0
    ) {
        self.method = method
        self.madhab = madhab
        self.highLatitudeRule = highLatitudeRule
        self.adjustments = adjustments.mapValues { max(-30, min(30, $0)) }
        self.hijriOffsetDays = max(-2, min(2, hijriOffsetDays))
    }
}

/// One civil day's times, adjustments applied.
public struct PrayerDay: Equatable, Sendable {
    public let date: DateComponents // y/m/d civil date at the location
    public let times: [PrayerName: Date]

    public func time(_ name: PrayerName) -> Date { times[name]! }

    /// Ordered for display.
    public var ordered: [(name: PrayerName, time: Date)] {
        PrayerName.allCases.map { ($0, times[$0]!) }
    }
}

public struct NextPrayerState: Equatable, Sendable {
    /// The prayer whose window we are in (nil before Fajr).
    public let current: PrayerName?
    public let next: PrayerName
    public let nextTime: Date
}

/// Deterministic prayer engine over PrayerCalculator. Pure: all inputs explicit,
/// no clock or location reads — callers own those effects.
public struct PrayerEngine: Sendable {
    private let calculator = PrayerCalculator()

    public init() {}

    public func day(
        latitude: Double,
        longitude: Double,
        date: DateComponents,
        settings: PrayerSettings
    ) throws -> PrayerDay {
        let rule = Self.effectiveHighLatitudeRule(settings: settings, latitude: latitude)
        let raw = try calculator.times(for: .init(
            latitude: latitude,
            longitude: longitude,
            date: date,
            method: settings.method,
            madhab: settings.madhab,
            highLatitudeRule: rule
        ))
        var times: [PrayerName: Date] = [
            .fajr: raw.fajr, .sunrise: raw.sunrise, .dhuhr: raw.dhuhr,
            .asr: raw.asr, .maghrib: raw.maghrib, .isha: raw.isha,
        ]
        for (name, minutes) in settings.adjustments where minutes != 0 {
            times[name] = times[name]!.addingTimeInterval(TimeInterval(minutes * 60))
        }
        return PrayerDay(date: date, times: times)
    }

    /// Spike policy (M0): explicit rule from config wins; ≥48° with no explicit
    /// rule → seventh-of-the-night — stated directly (not via the library's
    /// `recommended`) so iOS and Android are identical by construction.
    static func effectiveHighLatitudeRule(settings: PrayerSettings, latitude: Double) -> String? {
        if let rule = settings.highLatitudeRule { return rule }
        guard abs(latitude) >= PrayerSettings.highLatitudeThreshold else { return nil }
        return "seventh_of_the_night"
    }

    /// Timeline for scheduling/widgets: `days` consecutive days from `startDate`.
    public func timeline(
        latitude: Double,
        longitude: Double,
        startDate: DateComponents,
        days: Int,
        settings: PrayerSettings,
        calendar: Calendar = .init(identifier: .gregorian)
    ) throws -> [PrayerDay] {
        guard let start = calendar.date(from: startDate) else { return [] }
        return try (0..<days).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: start)!
            let components = calendar.dateComponents([.year, .month, .day], from: date)
            return try day(latitude: latitude, longitude: longitude, date: components, settings: settings)
        }
    }

    /// Next-prayer resolution across day boundaries. `today` and `tomorrow` must be
    /// consecutive (from `timeline`). Sunrise is never "next" — it is not a prayer.
    public static func nextPrayer(now: Date, today: PrayerDay, tomorrow: PrayerDay) -> NextPrayerState {
        let upcoming = today.ordered
            .filter { $0.name.isPrayer && $0.time > now }
        if let next = upcoming.first {
            let past = today.ordered.filter { $0.name.isPrayer && $0.time <= now }
            return NextPrayerState(current: past.last?.name, next: next.name, nextTime: next.time)
        }
        // After Isha: next is tomorrow's Fajr.
        return NextPrayerState(current: .isha, next: .fajr, nextTime: tomorrow.time(.fajr))
    }
}

/// Hijri date with the user/admin offset (ADR-0003: offset default is remote config).
public struct HijriDate: Equatable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int
    public let monthName: String

    public init(from date: Date, offsetDays: Int, locale: Locale = Locale(identifier: "ar")) {
        var calendar = Calendar(identifier: .islamicUmmAlQura)
        calendar.locale = locale
        let adjusted = calendar.date(byAdding: .day, value: offsetDays, to: date) ?? date
        let components = calendar.dateComponents([.year, .month, .day], from: adjusted)
        self.year = components.year ?? 0
        self.month = components.month ?? 0
        self.day = components.day ?? 0
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.dateFormat = "MMMM"
        self.monthName = formatter.string(from: adjusted)
    }
}
