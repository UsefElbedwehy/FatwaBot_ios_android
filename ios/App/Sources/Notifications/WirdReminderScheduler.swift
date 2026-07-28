import AwradFeature
import CoreKit
import Foundation
import UserNotifications

/// Registers the pure `WirdReminderPlanner` output with the OS, including the
/// notification category that carries the two answer buttons.
///
/// Lives in the App target rather than AwradFeature because it composes the
/// feature's data with a platform API and the shared notification budget —
/// the composition role ADR-0010 assigns to the app layer, same as
/// `ContentReminderScheduler`.
protocol WirdReminderScheduling: Sendable {
    func registerCategory()
    func reschedule(preferences: WirdReminderPreferences, wirds: [Wird]) async
}

final class WirdReminderScheduler: WirdReminderScheduling, @unchecked Sendable {
    /// The category the two actions hang off. Read back in
    /// `NotificationTapDelegate` to tell a wird reminder from a content one.
    static let categoryIdentifier = "wird.reminder"
    /// "نعم" — answered without opening the app.
    static let doneActionIdentifier = "wird.reminder.done"
    /// "لاحقاً" — dismiss, change nothing.
    static let laterActionIdentifier = "wird.reminder.later"
    /// The `userInfo` entry naming which wird is being asked about.
    static let wirdIdKey = "wirdId"

    private let center: UNUserNotificationCenter
    private let stringProvider: @Sendable (String) -> String

    init(
        center: UNUserNotificationCenter = .current(),
        stringProvider: @escaping @Sendable (String) -> String
    ) {
        self.center = center
        self.stringProvider = stringProvider
    }

    /// Must run before the first notification is *delivered*, not just before it
    /// is scheduled — an unregistered category renders as a plain banner with no
    /// buttons, which is the entire feature missing.
    func registerCategory() {
        let done = UNNotificationAction(
            identifier: Self.doneActionIdentifier,
            title: stringProvider("notif.wird.action.yes"),
            // No `.foreground`: the whole point is answering without opening the app.
            options: []
        )
        let later = UNNotificationAction(
            identifier: Self.laterActionIdentifier,
            title: stringProvider("notif.wird.action.later"),
            options: []
        )
        let category = UNNotificationCategory(
            identifier: Self.categoryIdentifier,
            actions: [done, later],
            intentIdentifiers: [],
            options: []
        )
        // Additive rather than a plain set, so registering ours can't drop a
        // category another feature registered.
        center.getNotificationCategories { existing in
            var merged = existing.filter { $0.identifier != Self.categoryIdentifier }
            merged.insert(category)
            self.center.setNotificationCategories(merged)
        }
    }

    func reschedule(preferences: WirdReminderPreferences, wirds: [Wird]) async {
        let plan = WirdReminderPlanner.plan(wirds: wirds, preferences: preferences)

        let pending = await center.pendingNotificationRequests()
        let ours = pending.map(\.identifier).filter { $0.hasPrefix(WirdReminderPlanner.idPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ours)

        for item in plan {
            let content = UNMutableNotificationContent()
            // "هل أكملت [اسم الورد]؟" — the name is in the title so the user knows
            // which wird they are answering for straight off the lock screen.
            content.title = String(format: stringProvider("notif.wird.title"), item.wirdName)
            content.body = stringProvider("notif.wird.body")
            content.sound = .default
            content.categoryIdentifier = Self.categoryIdentifier
            content.userInfo = [
                // Tapping the body (rather than a button) opens the Awrad screen.
                NotificationTapRouter.userInfoKey: DeepLink.awrad.rawValue,
                Self.wirdIdKey: item.wirdId,
            ]

            // One *repeating* daily trigger rather than one request per day: the
            // text never changes, and a rolling horizon would burn a pending slot
            // per wird per day. Overflow past iOS's 64 evicts the OLDEST pending
            // requests — the prayer notifications.
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: DateComponents(hour: item.hour, minute: item.minute), repeats: true
            )
            let request = UNNotificationRequest(identifier: item.id, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }
}
