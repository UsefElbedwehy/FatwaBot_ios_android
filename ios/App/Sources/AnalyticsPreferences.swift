import Foundation

/// The user's diagnostics choice, persisted locally (mirrors `AppearanceMode`'s
/// `@AppStorage` convention so Settings can bind to it directly).
///
/// Defaults to **enabled**: usage reporting is what tells us which worship
/// features earn their place, and nothing personal is collected (see
/// `CoreKit.AnalyticsTracking`). The opt-out exists because this is a worship app
/// — someone who would rather send nothing at all shouldn't have to uninstall to
/// get that.
enum AnalyticsPreferences {
    static let storageKey = "diagnostics.enabled"

    /// `UserDefaults.bool(forKey:)` is `false` when unset, so register the
    /// default rather than inverting the flag's meaning.
    static func registerDefaults(_ defaults: UserDefaults = .standard) {
        defaults.register(defaults: [storageKey: true])
    }

    static func isEnabled(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: storageKey) as? Bool ?? true
    }
}
