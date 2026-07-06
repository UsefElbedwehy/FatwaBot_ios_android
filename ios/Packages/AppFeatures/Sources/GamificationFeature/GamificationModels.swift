import Foundation

// MARK: - Local event queue (docs/features/gamification.md)

/// A locally queued, not-yet-confirmed-synced activity event.
public struct QueuedActivityEvent: Codable, Equatable, Sendable {
    public let clientEventId: String
    public let eventType: String
    public let occurredAt: Date
    public let timezone: String
    public let metadata: [String: String]

    public init(
        clientEventId: String = UUID().uuidString,
        eventType: String,
        occurredAt: Date = Date(),
        timezone: String = TimeZone.current.identifier,
        metadata: [String: String] = [:]
    ) {
        self.clientEventId = clientEventId
        self.eventType = eventType
        self.occurredAt = occurredAt
        self.timezone = timezone
        self.metadata = metadata
    }
}

/// Persistence boundary for the queue (mirrors TasbeehHistoryStoring).
public protocol ActivityEventQueueStoring: Sendable {
    func load() -> [QueuedActivityEvent]
    func save(_ events: [QueuedActivityEvent])
}

public struct FileActivityEventQueueStore: ActivityEventQueueStoring {
    private let fileURL: URL

    public init(directory: URL) {
        fileURL = directory.appendingPathComponent("gamification-event-queue.json")
    }

    public func load() -> [QueuedActivityEvent] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([QueuedActivityEvent].self, from: data)) ?? []
    }

    public func save(_ events: [QueuedActivityEvent]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(events) else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try? data.write(to: fileURL, options: .atomic)
    }
}

// MARK: - Server profile (GET /v1/gamification/profile)

public struct GamificationStreak: Decodable, Equatable, Identifiable, Sendable {
    public var id: String { key }
    public let key: String
    public let name: String
    public let currentLength: Int
    public let longestLength: Int
    public let graceRemaining: Int

    enum CodingKeys: String, CodingKey {
        case key, name
        case currentLength = "current_length"
        case longestLength = "longest_length"
        case graceRemaining = "grace_remaining"
    }
}

public struct GamificationMission: Decodable, Equatable, Identifiable, Sendable {
    public var id: String { key }
    public let key: String
    public let name: String
    public let progress: Int
    public let target: Int
    public let window: String
    public let endsAt: Date?

    enum CodingKeys: String, CodingKey {
        case key, name, progress, target, window
        case endsAt = "ends_at"
    }
}

public struct GamificationBadge: Decodable, Equatable, Identifiable, Sendable {
    public var id: String { key }
    public let key: String
    public let name: String
    public let iconRef: String
    public let earnedAt: Date?

    enum CodingKeys: String, CodingKey {
        case key, name
        case iconRef = "icon_ref"
        case earnedAt = "earned_at"
    }

    public var isEarned: Bool { earnedAt != nil }
}

public struct GamificationProfile: Decodable, Equatable, Sendable {
    public let streaks: [GamificationStreak]
    public let missions: [GamificationMission]
    public let badges: [GamificationBadge]

    public static let empty = GamificationProfile(streaks: [], missions: [], badges: [])
}
