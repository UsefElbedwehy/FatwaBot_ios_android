import Foundation

/// The data widgets render from — written by the app to the app-group container
/// and read by widget processes with zero network access (docs/features/prayer.md
/// widget architecture). Precomputed so WidgetKit/Glance build their own timelines.
public struct PrayerWidgetSnapshot: Codable, Equatable, Sendable {
    public struct Entry: Codable, Equatable, Sendable {
        public let prayer: String   // PrayerName.rawValue
        public let time: Date

        public init(prayer: String, time: Date) {
            self.prayer = prayer
            self.time = time
        }
    }

    /// A whole day as the day-sheet widgets render it.
    ///
    /// Separate from `upcoming` rather than folded into it, because the two
    /// answer different questions and merging them breaks one of them: the
    /// countdown widgets ask "what is the next *prayer*", and sunrise is a
    /// displayed time but not a prayer — putting it in `upcoming` would make the
    /// home screen announce الشروق as the next prayer every morning.
    public struct DaySheet: Codable, Equatable, Sendable {
        /// This day's Fajr — both the first row and the key this sheet is
        /// selected by.
        public let fajr: Date
        /// Every time in display order, sunrise included.
        public let times: [Entry]
        /// nil when the following day was beyond the snapshot horizon, or at
        /// latitudes where the night has no valid span (see `NightTimes`).
        public let midnight: Date?
        public let lastThird: Date?

        public init(fajr: Date, times: [Entry], midnight: Date?, lastThird: Date?) {
            self.fajr = fajr
            self.times = times
            self.midnight = midnight
            self.lastThird = lastThird
        }
    }

    public let locationName: String
    public let hijriMonthName: String
    public let hijriDay: Int
    public let hijriYear: Int
    /// Upcoming prayer times (48h ahead) so the widget timeline needs no refresh
    /// between location/settings changes.
    public let upcoming: [Entry]
    /// Full day sheets over the same horizon, for the widgets that show the
    /// whole day rather than the next prayer.
    public let days: [DaySheet]
    public let generatedAt: Date
    /// The resolved location's timezone — nil when it wasn't known (reverse-
    /// geocoding gave no timezone) or when read from a snapshot an older app
    /// build wrote before this field existed. See `timeZone`.
    public let timeZoneIdentifier: String?

    /// The location's timezone, falling back to the device's. Widgets display
    /// a prayer's *local* time at that location, not a device-timezone
    /// translation of it — same reasoning as `PrayerViewModel.displayTimeZone`.
    public var timeZone: TimeZone { timeZoneIdentifier.flatMap(TimeZone.init(identifier:)) ?? .current }

    public init(
        locationName: String,
        hijriMonthName: String,
        hijriDay: Int,
        hijriYear: Int,
        upcoming: [Entry],
        days: [DaySheet] = [],
        generatedAt: Date,
        timeZoneIdentifier: String? = nil
    ) {
        self.locationName = locationName
        self.hijriMonthName = hijriMonthName
        self.hijriDay = hijriDay
        self.hijriYear = hijriYear
        self.upcoming = upcoming
        self.days = days
        self.generatedAt = generatedAt
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    // Hand-written so that `days` decodes as empty rather than failing outright.
    // The widget extension can be running the new build against a snapshot the
    // *previous* app version wrote — synthesized Codable would treat the missing
    // key as a decode error, `read()` would return nil, and every prayer widget
    // on the home screen would fall back to its placeholder until the user next
    // opened the app. An empty day list degrades to "day sheet not ready"; a
    // failed decode takes the working widgets down with it.
    private enum CodingKeys: String, CodingKey {
        case locationName, hijriMonthName, hijriDay, hijriYear, upcoming, days, generatedAt, timeZoneIdentifier
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        locationName = try c.decode(String.self, forKey: .locationName)
        hijriMonthName = try c.decode(String.self, forKey: .hijriMonthName)
        hijriDay = try c.decode(Int.self, forKey: .hijriDay)
        hijriYear = try c.decode(Int.self, forKey: .hijriYear)
        upcoming = try c.decode([Entry].self, forKey: .upcoming)
        days = try c.decodeIfPresent([DaySheet].self, forKey: .days) ?? []
        generatedAt = try c.decode(Date.self, forKey: .generatedAt)
        timeZoneIdentifier = try c.decodeIfPresent(String.self, forKey: .timeZoneIdentifier)
    }

    /// The day sheet covering `date`.
    ///
    /// Selected by the latest Fajr at or before `date`, which deliberately keeps
    /// the *previous* day's sheet on screen through the small hours: at 01:00 the
    /// night markers a reader cares about — منتصف الليل and الثلث الأخير — belong
    /// to the night that began at yesterday's Maghrib and are still ahead of
    /// them. Rolling over at clock midnight would blank exactly the two rows the
    /// widget exists to show, at exactly the hour someone is up to read them.
    public func sheet(for date: Date) -> DaySheet? {
        days.last { $0.fajr <= date } ?? days.first
    }

    /// Next prayer strictly after `date`.
    public func nextEntry(after date: Date) -> Entry? {
        upcoming.first { $0.time > date }
    }

    /// Builds a widget snapshot from a precomputed prayer timeline.
    public static func build(
        timeline: [PrayerDay],
        location: String,
        hijri: HijriDate,
        generatedAt: Date,
        horizon: TimeInterval = 48 * 3600,
        timeZoneIdentifier: String? = nil
    ) -> PrayerWidgetSnapshot {
        let cutoff = generatedAt.addingTimeInterval(horizon)
        let entries = timeline
            .flatMap { day in day.ordered.filter { $0.name.isPrayer } }
            .filter { $0.time <= cutoff }
            .sorted { $0.time < $1.time }
            .map { Entry(prayer: $0.name.rawValue, time: $0.time) }

        // Day sheets keep every time, sunrise included — the opposite of the
        // `isPrayer` filter above, and the reason this is a second pass rather
        // than a reshaping of `entries`.
        let sheets: [DaySheet] = timeline.enumerated().compactMap { index, day in
            guard day.time(.fajr) <= cutoff else { return nil }
            let night = index + 1 < timeline.count
                ? NightTimes.between(
                    maghrib: day.time(.maghrib),
                    nextFajr: timeline[index + 1].time(.fajr)
                )
                : nil
            return DaySheet(
                fajr: day.time(.fajr),
                times: day.ordered.map { Entry(prayer: $0.name.rawValue, time: $0.time) },
                midnight: night?.midnight,
                lastThird: night?.lastThird
            )
        }

        return PrayerWidgetSnapshot(
            locationName: location,
            hijriMonthName: hijri.monthName,
            hijriDay: hijri.day,
            hijriYear: hijri.year,
            upcoming: entries,
            days: sheets,
            generatedAt: generatedAt,
            timeZoneIdentifier: timeZoneIdentifier
        )
    }
}

/// Shared read/write of the widget snapshot via the app-group container.
public struct WidgetSnapshotStore: Sendable {
    private let fileURL: URL

    public init(appGroupContainer: URL) {
        self.fileURL = appGroupContainer.appendingPathComponent("prayer-widget-snapshot.json")
    }

    public func write(_ snapshot: PrayerWidgetSnapshot) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snapshot) else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try? data.write(to: fileURL, options: .atomic)
    }

    public func read() -> PrayerWidgetSnapshot? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(PrayerWidgetSnapshot.self, from: data)
    }
}
