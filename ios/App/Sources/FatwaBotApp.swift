import AwradFeature
import ContentKit
import DesignSystemKit
import Factory
import NetworkingKit
import SwiftUI
import UserNotifications

@main
struct FatwaBotApp: App {
    @State private var theme = ThemeStore()
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
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(theme)
                .tint(Color(hexToken: theme.current(for: .light).primary))
                .preferredColorScheme((AppearanceMode(rawValue: appearanceRaw) ?? .system).colorScheme)
                .task {
                    await flushAnalytics()
                    await syncContent()
                }
                .onChange(of: scenePhase) { _, phase in
                    // Backgrounding is the natural batch boundary: it's when a
                    // session has actually ended, and the queue is otherwise only
                    // sent once it reaches the batch threshold — which a light
                    // user might never hit.
                    if phase == .background {
                        Task { await flushAnalytics() }
                    }
                    // Foregrounding is the other natural sync point: a long-lived
                    // app would otherwise never pick up published content after
                    // its one launch-time sync.
                    if phase == .active {
                        Task { await syncContent() }
                    }
                }
        }
    }

    /// Pulls published content on launch and on every foreground. Failures are
    /// silent by design — the bundled seed keeps the app fully usable offline.
    private func syncContent() async {
        await Container.shared.contentService().syncAll(locale: ContentLocale.current)
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
