import BackgroundTasks
import Foundation
import PrayerFeature

/// Extends the prayer notification schedule without the user opening the app.
///
/// ## Why this is needed at all
/// iOS allows 64 pending notification requests. The prayer schedule reserves 48
/// of them, and at five adhan a day that is roughly nine days of coverage. The
/// schedule only ever grew when the app came to the foreground, so a user who
/// did not open it for ten days simply stopped being called to prayer — with
/// nothing on screen to explain why. That is half of the reported
/// «الإشعارات في أيام ما تظهر».
///
/// A background refresh re-plans the rolling window periodically, so the horizon
/// moves forward on its own.
///
/// ## What this is not
/// `BGAppRefreshTask` is opportunistic. iOS decides when — and whether — to run
/// it, based on how often the user opens the app, battery, and network. It is a
/// *safety net that usually works*, not a guarantee, so it is layered on top of
/// the foreground reschedule rather than replacing it. Treating it as a
/// guarantee is how people ship schedulers that work on their own phone and fail
/// on someone else's.
enum PrayerScheduleRefreshTask {
    /// Must match the identifier declared in Info.plist under
    /// `BGTaskSchedulerPermittedIdentifiers`. iOS rejects registration for an
    /// identifier that is not declared, and the failure is a crash at launch.
    static let identifier = "com.fatwabot.app.prayer-refresh"

    /// Earliest the system may run it. A day is the useful floor: the schedule
    /// covers over a week, so a daily nudge keeps the horizon comfortably ahead
    /// without asking iOS for a budget it will refuse.
    private static let interval: TimeInterval = 24 * 3600

    /// Registers the handler. Must be called before the app finishes launching —
    /// registering later throws, and iOS treats that as a programmer error.
    static func register(reschedule: @escaping @Sendable () async -> Void) {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: identifier, using: nil
        ) { task in
            // Submit the *next* request first. If the work below throws, is
            // cancelled, or the process is killed, a chain that only re-submits
            // on success stops forever after its first bad run.
            submit()

            let work = Task {
                await reschedule()
                task.setTaskCompleted(success: true)
            }
            // iOS gives a few seconds and then kills the process if the task has
            // not finished. Cancelling lets the work unwind rather than being
            // terminated mid-write.
            task.expirationHandler = { work.cancel() }
        }
    }

    /// Asks iOS to run the task no earlier than `interval` from now.
    ///
    /// Failures are swallowed on purpose: submission throws when the app is in
    /// an unexpected state or a request is already queued, and neither is worth
    /// surfacing to a user who cannot act on it. The foreground reschedule still
    /// covers them.
    static func submit() {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: interval)
        try? BGTaskScheduler.shared.submit(request)
    }
}
