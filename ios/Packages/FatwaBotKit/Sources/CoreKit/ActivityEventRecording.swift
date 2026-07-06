import Foundation

/// Activity-event recording boundary shared by any feature whose completion
/// moments feed the gamification engine (Azkar, Tasbeeh, Awrad, Hadith
/// Collections, ...). Lives in CoreKit, not GamificationFeature, so those
/// features never depend on GamificationFeature directly (ADR-0010:
/// feature -> feature is forbidden) — mirrors the HapticsProviding pattern.
public protocol ActivityEventRecording: Sendable {
    /// Fire-and-forget: queues locally and flushes opportunistically
    /// (docs/features/gamification.md). Never blocks or throws to the caller.
    func record(eventType: String, metadata: [String: String])
}

public struct NoopActivityEventRecording: ActivityEventRecording {
    public init() {}
    public func record(eventType: String, metadata: [String: String]) {}
}
