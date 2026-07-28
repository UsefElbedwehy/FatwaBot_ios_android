import ContentKit
import Foundation

/// Persistence for the daily azkar/hadith reminder settings. Deliberately a
/// separate blob from `notifications.prayer.preferences.v1` — the two are edited
/// independently, and sharing a key would mean a decode failure in one wiped the
/// other.
protocol ContentReminderPreferenceStoring: Sendable {
    func load() -> ContentReminderPreferences
    func save(_ preferences: ContentReminderPreferences)
}

final class UserDefaultsContentReminderPreferenceStore: ContentReminderPreferenceStoring, @unchecked Sendable {
    private static let key = "notifications.content.preferences.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Falls back to first-run defaults (on, 2/day) rather than throwing: a
    /// corrupt blob should cost the user their customisation, not their reminders.
    func load() -> ContentReminderPreferences {
        guard let data = defaults.data(forKey: Self.key),
              let decoded = try? JSONDecoder().decode(ContentReminderPreferences.self, from: data)
        else { return ContentReminderPreferences() }
        return decoded
    }

    func save(_ preferences: ContentReminderPreferences) {
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
