import Foundation
import PrayerKit
#if canImport(UserNotifications)
import UserNotifications
#endif

/// Registers the pure `NotificationPlanner` output with the OS. Reschedules on
/// the triggers from docs/features/prayer.md (foreground, settings change,
/// significant location change, daily background refresh).
public protocol PrayerNotificationScheduling: Sendable {
    func requestAuthorization() async -> Bool
    /// Replace all pending prayer notifications with a freshly built plan.
    func reschedule(
        timeline: [PrayerDay],
        preferences: PrayerNotificationPreferences,
        now: Date
    ) async
}

#if canImport(UserNotifications)
public final class PrayerNotificationScheduler: PrayerNotificationScheduling, @unchecked Sendable {
    private let center: UNUserNotificationCenter
    private let stringProvider: @Sendable (String) -> String
    private static let categoryPrefix = "prayer."

    /// - Parameter stringProvider: resolves a template key to localized text
    ///   (server string pack overlay → bundle). Injected so the scheduler stays
    ///   independent of the config layer.
    public init(
        center: UNUserNotificationCenter = .current(),
        stringProvider: @escaping @Sendable (String) -> String
    ) {
        self.center = center
        self.stringProvider = stringProvider
    }

    public func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    public func reschedule(
        timeline: [PrayerDay],
        preferences: PrayerNotificationPreferences,
        now: Date
    ) async {
        let plan = NotificationPlanner.plan(timeline: timeline, preferences: preferences, now: now)

        // Clear only our prayer notifications, leaving other categories intact.
        let pending = await center.pendingNotificationRequests()
        let ours = pending.map(\.identifier).filter { $0.hasPrefix("adhan-") || $0.hasPrefix("pre-") }
        center.removePendingNotificationRequests(withIdentifiers: ours)

        for item in plan {
            let content = UNMutableNotificationContent()
            content.title = stringProvider(item.titleKey)
            content.body = stringProvider(item.bodyKey)
            content.sound = item.kind == .adhan ? .default : .default
            content.categoryIdentifier = Self.categoryPrefix + item.kind.rawValue

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: item.fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: item.id, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }
}
#endif
