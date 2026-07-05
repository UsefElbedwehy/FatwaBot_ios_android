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

    public let locationName: String
    public let hijriMonthName: String
    public let hijriDay: Int
    public let hijriYear: Int
    /// Upcoming prayer times (48h ahead) so the widget timeline needs no refresh
    /// between location/settings changes.
    public let upcoming: [Entry]
    public let generatedAt: Date

    public init(
        locationName: String,
        hijriMonthName: String,
        hijriDay: Int,
        hijriYear: Int,
        upcoming: [Entry],
        generatedAt: Date
    ) {
        self.locationName = locationName
        self.hijriMonthName = hijriMonthName
        self.hijriDay = hijriDay
        self.hijriYear = hijriYear
        self.upcoming = upcoming
        self.generatedAt = generatedAt
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
        horizon: TimeInterval = 48 * 3600
    ) -> PrayerWidgetSnapshot {
        let cutoff = generatedAt.addingTimeInterval(horizon)
        let entries = timeline
            .flatMap { day in day.ordered.filter { $0.name.isPrayer } }
            .filter { $0.time <= cutoff }
            .sorted { $0.time < $1.time }
            .map { Entry(prayer: $0.name.rawValue, time: $0.time) }
        return PrayerWidgetSnapshot(
            locationName: location,
            hijriMonthName: hijri.monthName,
            hijriDay: hijri.day,
            hijriYear: hijri.year,
            upcoming: entries,
            generatedAt: generatedAt
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
