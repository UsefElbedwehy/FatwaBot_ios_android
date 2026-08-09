import AwradFeature
import BackgroundTasks
import ContentKit
import DesignSystemKit
import Factory
import NetworkingKit
import SwiftUI
import UserNotifications

@main
struct FatwaBotApp: App {
    @State private var theme = ThemeStore()
    @State private var syncStatus = ContentSyncStatus()
    @AppStorage(AppearanceMode.storageKey) private var appearanceRaw = AppearanceMode.system.rawValue
    @Environment(\.scenePhase) private var scenePhase

    init() {
        AnalyticsPreferences.registerDefaults()
        // Must be set before the app finishes launching, or a tap that cold-starts
        // the app is delivered before anyone is listening and the deep link is lost.
        UNUserNotificationCenter.current().delegate = NotificationTapDelegate.shared
        // Same reason: the "نعم"/"لاحقاً" buttons only render if the category is
        // registered before the notification is delivered, and a reminder can be
        // delivered the instant the app finishes launching.
        Container.shared.wirdReminderScheduler().registerCategory()
        // Also launch-time only: BGTaskScheduler rejects a handler registered
        // after the app has finished launching.
        PrayerScheduleRefreshTask.register {
            await Container.shared.prayerViewModel().rescheduleNotifications()
        }
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(theme)
                .environment(syncStatus)
                .tint(Color(hexToken: theme.current(for: .light).primary))
                .preferredColorScheme((AppearanceMode(rawValue: appearanceRaw) ?? .system).colorScheme)
                .task {
                    await flushAnalytics()
                    await drainWorshipInbox()
                    await syncContent()
                }
                // Flying somewhere else moves the clock underneath a schedule
                // computed for the old location. Prayer times are absolute
                // instants, so nothing about them shifts on its own — they are
                // simply wrong on arrival until something re-plans.
                //
                // iOS has no reboot problem to solve (pending notifications
                // survive), so unlike Android this is the only trigger needed.
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: Notification.Name.NSSystemTimeZoneDidChange
                    )
                ) { _ in
                    Task { await Container.shared.prayerViewModel().rescheduleNotifications() }
                }
                .onChange(of: scenePhase) { _, phase in
                    // Backgrounding is the natural batch boundary: it's when a
                    // session has actually ended, and the queue is otherwise only
                    // sent once it reaches the batch threshold — which a light
                    // user might never hit.
                    if phase == .background {
                        Task { await flushAnalytics() }
                        // Queued on the way out: iOS only runs background refresh
                        // for apps that are not in the foreground, so submitting
                        // here is the moment it becomes eligible.
                        PrayerScheduleRefreshTask.submit()
                    }
                    // Foregrounding is the other natural sync point: a long-lived
                    // app would otherwise never pick up published content after
                    // its one launch-time sync.
                    if phase == .active {
                        Task { await syncContent() }
                        // Taps made on the home screen while the app was away.
                        // Foreground is the first moment we can upload them, and
                        // the streak stays wrong until we do.
                        Task { await drainWorshipInbox() }
                    }
                }
        }
    }

    /// Uploads worship logged from the متابعة العبادات widget.
    ///
    /// Silent on failure like every other queue flush: entries stay in the
    /// inbox — or, once adopted, in the event queue — and are retried on the
    /// next foreground. Nothing is dropped by a failed attempt.
    private func drainWorshipInbox() async {
        guard let inbox = Container.shared.worshipInbox() else { return }
        await Container.shared.gamificationEventRecorder().drain(inbox)
    }

    /// Pulls published content on launch and on every foreground. Failures are
    /// silent by design — the bundled seed keeps the app fully usable offline.
    private func syncContent() async {
        syncStatus.beginSync()
        let summary = await Container.shared.contentService().syncAll(locale: ContentLocale.current)
        syncStatus.finish(summary)
    }

    private func flushAnalytics() async {
        await (Container.shared.analyticsTracking() as? BackendAnalyticsRecorder)?.flush()
    }
}

/// Holds resolved design tokens. M0: bundled defaults only; the /v1/config/theme
/// overlay lands with the config sync service in M1.
@Observable
final class ThemeStore {
    private(set) var tokens: DesignTokens = .bundledDefault

    func current(for scheme: ColorScheme) -> ColorTokens {
        scheme == .dark ? tokens.dark : tokens.light
    }
}
