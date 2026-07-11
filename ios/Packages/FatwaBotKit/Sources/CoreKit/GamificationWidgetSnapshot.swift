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
    public let generatedAt: Date

    public init(topStreak: Streak?, dailyChallenge: DailyChallenge?, generatedAt: Date) {
        self.topStreak = topStreak
        self.dailyChallenge = dailyChallenge
        self.generatedAt = generatedAt
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
