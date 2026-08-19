import Foundation

/// The data the Streak/Daily-Challenge widgets render from — written by the
/// app to the app-group container and read by widget processes with zero
/// network access (mirrors PrayerKit's PrayerWidgetSnapshot). Only the single
/// most relevant streak/mission are kept: widgets show one headline number,
/// not the full profile (the app is the place for that).
public struct GamificationWidgetSnapshot: Codable, Equatable, Sendable {
    public struct Streak: Codable, Equatable, Sendable {
        public let name: String
        public let currentLength: Int
        public let longestLength: Int
        public let graceRemaining: Int

        public init(name: String, currentLength: Int, longestLength: Int, graceRemaining: Int) {
            self.name = name
            self.currentLength = currentLength
            self.longestLength = longestLength
            self.graceRemaining = graceRemaining
        }
    }

    public struct DailyChallenge: Codable, Equatable, Sendable {
        public let name: String
        public let progress: Int
        public let target: Int

        public init(name: String, progress: Int, target: Int) {
            self.name = name
            self.progress = progress
            self.target = target
        }
    }

    public let topStreak: Streak?
    public let dailyChallenge: DailyChallenge?
    /// Deed keys the app has already recorded for the current local day, e.g.
    /// `["fajr", "azkar_morning"]`.
    ///
    /// The tracker widget needs this to render a tile as done. It cannot derive
    /// it from `WorshipInbox` alone: the inbox holds only what has *not* yet
    /// been drained, so every tile would revert to undone the moment the app
    /// next opened — the exact moment the deed became durable.
    public let completedToday: [String]
    public let generatedAt: Date

    public init(
        topStreak: Streak?,
        dailyChallenge: DailyChallenge?,
        completedToday: [String] = [],
        generatedAt: Date
    ) {
        self.topStreak = topStreak
        self.dailyChallenge = dailyChallenge
        self.completedToday = completedToday
        self.generatedAt = generatedAt
    }

    // Hand-written so `completedToday` defaults rather than failing the decode.
    // The widget extension reads whatever the *previous* app version wrote; a
    // synthesized decoder would treat the missing key as an error and take the
    // streak and daily-challenge widgets down with it.
    private enum CodingKeys: String, CodingKey {
        case topStreak, dailyChallenge, completedToday, generatedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        topStreak = try c.decodeIfPresent(Streak.self, forKey: .topStreak)
        dailyChallenge = try c.decodeIfPresent(DailyChallenge.self, forKey: .dailyChallenge)
        completedToday = try c.decodeIfPresent([String].self, forKey: .completedToday) ?? []
        generatedAt = try c.decode(Date.self, forKey: .generatedAt)
    }
}

/// Shared read/write of the widget snapshot via the app-group container.
public struct GamificationWidgetSnapshotStore: Sendable {
    private let fileURL: URL

    public init(appGroupContainer: URL) {
        self.fileURL = appGroupContainer.appendingPathComponent("gamification-widget-snapshot.json")
    }

    public func write(_ snapshot: GamificationWidgetSnapshot) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snapshot) else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try? data.write(to: fileURL, options: .atomic)
    }

    public func read() -> GamificationWidgetSnapshot? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(GamificationWidgetSnapshot.self, from: data)
    }
}
