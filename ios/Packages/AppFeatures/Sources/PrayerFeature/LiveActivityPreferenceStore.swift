import Foundation

/// Opt-out preference for the prayer countdown Live Activity — on by default
/// per stakeholder direction (2026-07-11), overriding ADR-0016's original
/// off-by-default decision. `UserDefaults.register(defaults:)` supplies the
/// default `true` so `bool(forKey:)` still returns the user's explicit choice
/// once they've toggled Settings, but reads `true` on a fresh install.
public protocol LiveActivityPreferenceStoring: Sendable {
    func isEnabled() -> Bool
    func setEnabled(_ enabled: Bool)
}

public final class UserDefaultsLiveActivityPreferenceStore: LiveActivityPreferenceStoring, @unchecked Sendable {
    private static let key = "liveActivity.prayerCountdown.enabled"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [Self.key: true])
    }

    public func isEnabled() -> Bool {
        defaults.bool(forKey: Self.key)
    }

    public func setEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: Self.key)
    }
}
