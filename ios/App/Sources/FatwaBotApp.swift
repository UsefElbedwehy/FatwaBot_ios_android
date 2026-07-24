import DesignSystemKit
import SwiftUI

@main
struct FatwaBotApp: App {
    @State private var theme = ThemeStore()
    @AppStorage(AppearanceMode.storageKey) private var appearanceRaw = AppearanceMode.system.rawValue

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(theme)
                .tint(Color(hexToken: theme.current(for: .light).primary))
                .preferredColorScheme((AppearanceMode(rawValue: appearanceRaw) ?? .system).colorScheme)
        }
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
