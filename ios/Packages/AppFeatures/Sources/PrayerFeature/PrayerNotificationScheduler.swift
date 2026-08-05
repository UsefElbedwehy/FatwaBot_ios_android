import CoreKit
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
        let prefixes = ["adhan-", "pre-", "iqama-", "lastthird-"]
        let pending = await center.pendingNotificationRequests()
        let ours = pending.map(\.identifier).filter { id in prefixes.contains { id.hasPrefix($0) } }
        center.removePendingNotificationRequests(withIdentifiers: ours)

        for item in plan {
            let content = UNMutableNotificationContent()
            content.title = stringProvider(item.titleKey)
            content.body = stringProvider(item.bodyKey)
            // The adhan is the call itself and should carry more weight than the
            // nudge that precedes it. `Sound.adhan` resolves to a bundled audio
            // file when one is present and falls back to the system default, so
            // this is correct today and improves the moment audio is added.
            //
            // Previously this read `item.kind == .adhan ? .default : .default` —
            // a ternary whose branches were identical, so the intent was written
            // down but never actually took effect.
            content.sound = item.kind == .adhan ? NotificationSound.adhan : .default
            content.categoryIdentifier = Self.categoryPrefix + item.kind.rawValue
            // Without this the tap handler has no route and the tap does nothing.
            // Every prayer kind (adhan, pre-adhan, iqama, last-third) lands on
            // the Prayer screen.
            content.userInfo = [DeepLink.notificationUserInfoKey: DeepLink.prayer.rawValue]

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
