import Foundation

/// Search-history recording boundary shared by any feature with an in-app
/// search box (Dua today; Azkar/Hadith Collections once they gain one).
/// Lives in CoreKit so those features never depend on SearchHistoryFeature
/// directly (ADR-0010) — mirrors ActivityEventRecording.
public protocol SearchHistoryRecording: Sendable {
    /// Fire-and-forget: never blocks or throws to the caller
    /// (docs/features/search-history.md — failures are silent).
    func record(source: String, queryText: String, locale: String)
}

public struct NoopSearchHistoryRecording: SearchHistoryRecording {
    public init() {}
    public func record(source: String, queryText: String, locale: String) {}
}
