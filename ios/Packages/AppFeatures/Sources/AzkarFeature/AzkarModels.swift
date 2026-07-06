import Foundation

/// Persisted mid-session position (docs/features/azkar.md: "Resume mid-session
/// after app restart same day restores exact position").
public struct AzkarSessionState: Codable, Equatable, Sendable {
    public let categoryId: String
    public var currentItemIndex: Int
    public var currentItemCount: Int
    public var lastTouchedAt: Date

    public init(categoryId: String, currentItemIndex: Int, currentItemCount: Int, lastTouchedAt: Date) {
        self.categoryId = categoryId
        self.currentItemIndex = currentItemIndex
        self.currentItemCount = currentItemCount
        self.lastTouchedAt = lastTouchedAt
    }
}

/// Local completion history — feeds the "completed today" badge and, later,
/// the M3 streak engine's activity events.
public struct AzkarCompletionRecord: Codable, Equatable, Sendable {
    public let categoryId: String
    public let completedAt: Date

    public init(categoryId: String, completedAt: Date) {
        self.categoryId = categoryId
        self.completedAt = completedAt
    }
}

public protocol AzkarStoring: Sendable {
    func loadSession() -> AzkarSessionState?
    func saveSession(_ session: AzkarSessionState?)
    func loadCompletions() -> [AzkarCompletionRecord]
    func recordCompletion(_ record: AzkarCompletionRecord)
}

public struct FileAzkarStore: AzkarStoring {
    private let sessionURL: URL
    private let completionsURL: URL

    public init(directory: URL) {
        sessionURL = directory.appendingPathComponent("azkar-session.json")
        completionsURL = directory.appendingPathComponent("azkar-completions.json")
    }

    public func loadSession() -> AzkarSessionState? {
        guard let data = try? Data(contentsOf: sessionURL) else { return nil }
        return try? JSONDecoder().decode(AzkarSessionState.self, from: data)
    }

    public func saveSession(_ session: AzkarSessionState?) {
        guard let session else {
            try? FileManager.default.removeItem(at: sessionURL)
            return
        }
        guard let data = try? JSONEncoder().encode(session) else { return }
        try? FileManager.default.createDirectory(
            at: sessionURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try? data.write(to: sessionURL, options: .atomic)
    }

    public func loadCompletions() -> [AzkarCompletionRecord] {
        guard let data = try? Data(contentsOf: completionsURL) else { return [] }
        return (try? JSONDecoder().decode([AzkarCompletionRecord].self, from: data)) ?? []
    }

    public func recordCompletion(_ record: AzkarCompletionRecord) {
        var all = loadCompletions()
        all.append(record)
        guard let data = try? JSONEncoder().encode(all) else { return }
        try? FileManager.default.createDirectory(
            at: completionsURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try? data.write(to: completionsURL, options: .atomic)
    }
}
