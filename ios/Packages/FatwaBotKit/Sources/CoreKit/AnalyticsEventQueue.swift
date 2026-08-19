import Foundation

/// One queued analytics event. `clientEventId` is what makes the ingest
/// idempotent — a flush that fails after the server committed can be retried
/// without double-counting.
public struct QueuedAnalyticsEvent: Codable, Sendable, Equatable {
    public let clientEventId: String
    public let name: String
    public let params: [String: String]
    public let occurredAt: Date

    public init(
        clientEventId: String = UUID().uuidString,
        name: String,
        params: [String: String] = [:],
        occurredAt: Date = Date()
    ) {
        self.clientEventId = clientEventId
        self.name = name
        self.params = params
        self.occurredAt = occurredAt
    }
}

public protocol AnalyticsEventQueueStoring: Sendable {
    func load() -> [QueuedAnalyticsEvent]
    func save(_ events: [QueuedAnalyticsEvent])
}

/// Disk-backed queue so events survive a cold start and an offline stretch —
/// mirrors `FileActivityEventQueueStore`.
///
/// The queue is **capped**: analytics is the least important thing the app does,
/// so a user who is offline for a week must not accumulate an unbounded file (or
/// a giant first flush). Oldest events are dropped once the cap is reached.
public struct FileAnalyticsEventQueueStore: AnalyticsEventQueueStoring {
    public static let maxQueued = 500

    private let fileURL: URL

    public init(directory: URL) {
        fileURL = directory.appendingPathComponent("analytics-event-queue.json")
    }

    public func load() -> [QueuedAnalyticsEvent] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([QueuedAnalyticsEvent].self, from: data)) ?? []
    }

    public func save(_ events: [QueuedAnalyticsEvent]) {
        let trimmed = events.count > Self.maxQueued ? Array(events.suffix(Self.maxQueued)) : events
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(trimmed) else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try? data.write(to: fileURL, options: .atomic)
    }
}
