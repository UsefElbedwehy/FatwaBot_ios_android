import Foundation

/// Tracks whether the value-first onboarding flow (docs/features/onboarding.md)
/// has been completed on this install. Local-only — onboarding runs before any
/// identity exists, so there is nothing server-side to attach this to; a
/// reinstall sees onboarding again, which is acceptable.
public struct OnboardingCompletionStore: Sendable {
    private struct Payload: Codable {
        let completed: Bool
        let completedAt: Date
    }

    private let fileURL: URL

    public init(directory: URL) {
        fileURL = directory.appendingPathComponent("onboarding-completion.json")
    }

    public func isCompleted() -> Bool {
        guard let data = try? Data(contentsOf: fileURL) else { return false }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(Payload.self, from: data))?.completed ?? false
    }

    public func markCompleted(at date: Date = Date()) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(Payload(completed: true, completedAt: date)) else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try? data.write(to: fileURL, options: .atomic)
    }
}
