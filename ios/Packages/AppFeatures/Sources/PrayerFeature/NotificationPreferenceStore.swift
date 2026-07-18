import Foundation
import PrayerKit

/// Persists the user's per-type notification preferences (adhan / pre-adhan /
/// iqama / last-third) so choices survive relaunches. Mirrors the
/// `LiveActivityPreferenceStore` pattern; JSON-encoded in `UserDefaults`.
public protocol NotificationPreferenceStoring: Sendable {
    func load() -> PrayerNotificationPreferences
    func save(_ preferences: PrayerNotificationPreferences)
}

public final class UserDefaultsNotificationPreferenceStore: NotificationPreferenceStoring, @unchecked Sendable {
    private static let key = "notifications.prayer.preferences.v1"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> PrayerNotificationPreferences {
        guard let data = defaults.data(forKey: Self.key),
              let prefs = try? JSONDecoder().decode(PrayerNotificationPreferences.self, from: data)
        else { return PrayerNotificationPreferences() } // first-run defaults
        return prefs
    }

    public func save(_ preferences: PrayerNotificationPreferences) {
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
