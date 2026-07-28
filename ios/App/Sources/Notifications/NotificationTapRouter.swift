import CoreKit
import Foundation
import Observation
import UserNotifications

/// Bridges a local-notification tap onto the same `DeepLink` routing that widget
/// and Live Activity taps already use.
///
/// A notification tap does **not** produce a URL open, so `RootTabView`'s
/// `.onOpenURL` never sees it. Without this bridge an azkar reminder would just
/// dismiss and leave the user on whatever screen they were last on — the tap
/// would silently do nothing, which is exactly the class of failure
/// `CoreKit.DeepLink` exists to prevent.
@MainActor
@Observable
final class NotificationTapRouter {
    static let shared = NotificationTapRouter()

    /// The `userInfo` entry carrying `DeepLink.rawValue`.
    nonisolated static let userInfoKey = "deepLink"

    /// Set by the delegate, observed and cleared by `RootTabView`.
    var pendingLink: DeepLink?

    private init() {}

    func consume() {
        pendingLink = nil
    }
}

/// The `UNUserNotificationCenterDelegate` itself. Kept off `NotificationTapRouter`
/// because the delegate is called on a non-main thread and `NSObject` conformance
/// doesn't mix with `@Observable`.
final class NotificationTapDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationTapDelegate()

    /// Reminders are worth showing even while the app is open — otherwise iOS
    /// swallows them entirely and the day's reminder is simply lost.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let raw = response.notification.request.content.userInfo[NotificationTapRouter.userInfoKey] as? String
        if let raw, let link = DeepLink(rawValue: raw) {
            Task { @MainActor in NotificationTapRouter.shared.pendingLink = link }
        }
        completionHandler()
    }
}
