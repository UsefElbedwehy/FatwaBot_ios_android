import DesignSystemKit
import Factory
import NetworkingKit
import SwiftUI

@main
struct FatwaBotApp: App {
    @State private var theme = ThemeStore()
    @AppStorage(AppearanceMode.storageKey) private var appearanceRaw = AppearanceMode.system.rawValue
    @Environment(\.scenePhase) private var scenePhase

    init() {
        AnalyticsPreferences.registerDefaults()
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(theme)
                .tint(Color(hexToken: theme.current(for: .light).primary))
                .preferredColorScheme((AppearanceMode(rawValue: appearanceRaw) ?? .system).colorScheme)
                .task { await flushAnalytics() }
                .onChange(of: scenePhase) { _, phase in
                    // Backgrounding is the natural batch boundary: it's when a
                    // session has actually ended, and the queue is otherwise only
                    // sent once it reaches the batch threshold — which a light
                    // user might never hit.
                    if phase == .background {
                        Task { await flushAnalytics() }
                    }
                }
        }
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
