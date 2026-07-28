import AwradFeature
import Foundation

/// Persistence for the daily wird reminder settings. Its own blob, for the same
/// reason `ContentReminderPreferenceStore` is separate from the prayer one: the
/// three are edited independently, and sharing a key would mean a decode failure
/// in one silently wiping the others.
protocol WirdReminderPreferenceStoring: Sendable {
    func load() -> WirdReminderPreferences
    func save(_ preferences: WirdReminderPreferences)
}

final class UserDefaultsWirdReminderPreferenceStore: WirdReminderPreferenceStoring, @unchecked Sendable {
    private static let key = "notifications.wird.preferences.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Falls back to first-run defaults (on, 20:00) rather than throwing: a
    /// corrupt blob should cost the user their chosen hour, not their reminders.
    func load() -> WirdReminderPreferences {
        guard let data = defaults.data(forKey: Self.key),
              let decoded = try? JSONDecoder().decode(WirdReminderPreferences.self, from: data)
        else { return WirdReminderPreferences() }
        return decoded
    }

    func save(_ preferences: WirdReminderPreferences) {
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
