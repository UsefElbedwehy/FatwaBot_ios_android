import Foundation

/// Product-analytics boundary. Lives in CoreKit (mirrors `ActivityEventRecording`
/// and `HapticsProviding`) so feature modules depend on the protocol, never on a
/// transport or a vendor SDK, and stay testable with `NoopAnalyticsTracking`.
///
/// On iOS this is backed by our OWN ingest (`POST /v1/analytics/events`) rather
/// than a third-party SDK — see docs/features/analytics-and-crash-reporting.md.
///
/// ## What must never be sent
///
/// This is a worship app used by anonymous users. Treat the following as
/// forbidden payloads, not merely discouraged (the server rejects them too):
///
///  - **Search queries.** "Is X permissible" is among the most sensitive things a
///    user types. Report *that* a search happened, never *what* it said.
///  - **Location.** Not coordinates, not city. Prayer times are computed
///    on-device (ADR-0003) precisely so location never leaves it.
///  - **Identity.** No display name, email, user id, or push token.
///  - **Content bodies.** Du'a/hadith text or personal wird notes. A stable id or
///    category key is fine; free text is not.
///
/// Screen names, stable category keys and counts are the intended payloads.
public protocol AnalyticsTracking: Sendable {
    /// A screen became visible. `screen` must be a stable, non-PII key.
    func screenView(_ screen: String)

    /// A product event. `params` values must be stable keys or numbers — never
    /// user-authored text (see above).
    func event(_ name: String, params: [String: String])

    /// A handled error, for triage. Only the error's *type* is reported — never
    /// its message, which can carry user data.
    func nonFatal(_ error: Error)
}

public extension AnalyticsTracking {
    func event(_ name: String) { event(name, params: [:]) }
}

public struct NoopAnalyticsTracking: AnalyticsTracking {
    public init() {}
    public func screenView(_ screen: String) {}
    public func event(_ name: String, params: [String: String]) {}
    public func nonFatal(_ error: Error) {}
}

/// Canonical event + screen names, so the same concept isn't reported as
/// `dua_opened` here and `open_dua` there — which silently splits a metric
/// across two names and stays invisible until someone questions the numbers.
/// Kept identical to Android's `AnalyticsEvents` so one dashboard serves both.
public enum AnalyticsEvents {
    // Screens
    public static let screenHome = "home"
    public static let screenWorship = "worship"
    public static let screenSettings = "settings"
    public static let screenPrayer = "prayer_times"
    public static let screenQibla = "qibla"
    public static let screenTasbeeh = "tasbeeh"
    public static let screenAzkar = "azkar"
    public static let screenDua = "dua"
    public static let screenAwrad = "awrad"
    public static let screenHadith = "hadith"
    public static let screenJourney = "journey"

    // Events
    public static let screenView = "screen_view"
    public static let widgetOpenedApp = "widget_opened_app"
    public static let searchSubmitted = "search_submitted"
    public static let nonFatalError = "non_fatal_error"
    public static let tasbeehSessionCompleted = "tasbeeh_session_completed"
    public static let azkarCategoryCompleted = "azkar_category_completed"
    public static let notificationPrefsChanged = "notification_prefs_changed"

    // Param keys
    public static let paramScreen = "screen"
    public static let paramRoute = "route"
    public static let paramCategory = "category"
    public static let paramCount = "count"
    public static let paramErrorType = "error_type"
}
