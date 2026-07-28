import AwradFeature
import CoreKit
import Factory
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

    /// iOS permits exactly ONE delegate for the whole process, so every
    /// notification response — content reminder taps and wird answer buttons
    /// alike — funnels through here.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        switch response.actionIdentifier {
        case WirdReminderScheduler.doneActionIdentifier:
            // The answer path. Deliberately does NOT set `pendingLink`: the whole
            // promise is that "نعم" costs the user nothing but a tap — no app
            // launch, no screen to dismiss.
            if let wirdId = userInfo[WirdReminderScheduler.wirdIdKey] as? String {
                answerWirdCompleted(wirdId: wirdId)
            }
        case WirdReminderScheduler.laterActionIdentifier:
            // "لاحقاً" is an explicit no-op — the notification is already dismissed
            // by the time we get here, and tomorrow's repeat is unaffected.
            break
        default:
            // Includes `UNNotificationDefaultActionIdentifier` (the body was
            // tapped) — route it exactly as before.
            if let raw = userInfo[NotificationTapRouter.userInfoKey] as? String,
               let link = DeepLink(rawValue: raw) {
                Task { @MainActor in NotificationTapRouter.shared.pendingLink = link }
            }
        }

        completionHandler()
    }

    /// Resolves the responder fresh from the container rather than holding one:
    /// this delegate is a process-lifetime singleton that may be constructed
    /// before the container is configured, and the mutation is cheap.
    ///
    /// Runs off the main actor by design — when this fires the app is usually
    /// backgrounded or was just cold-started by the tap, so there is no
    /// `AwradViewModel` alive to mutate. `WirdCompletionResponder` writes through
    /// `WirdStoring` directly, and the view model re-reads the store on `.active`.
    private func answerWirdCompleted(wirdId: String) {
        Container.shared.wirdCompletionResponder().answerCompleted(wirdId: wirdId)
    }
}
