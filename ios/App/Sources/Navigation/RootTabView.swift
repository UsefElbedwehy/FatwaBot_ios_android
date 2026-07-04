import DesignSystemKit
import SwiftUI

struct RootTabView: View {
    @Environment(ThemeStore.self) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @State private var selection: AppTab = .home

    var body: some View {
        TabView(selection: $selection) {
            ForEach(AppTab.allCases) { tab in
                NavigationStack {
                    placeholder(for: tab)
                        .navigationTitle(Text(tab.titleKey))
                        .background(Color(hexToken: colors.surface))
                }
                .tabItem { Label(tab.titleKey, systemImage: tab.systemImage) }
                .tag(tab)
            }
        }
    }

    private var colors: ColorTokens {
        theme.current(for: colorScheme)
    }

    /// M0 shell: themed placeholders. Feature views replace these per milestone —
    /// Home renders the server-composed section list from /v1/home in M1.
    private func placeholder(for tab: AppTab) -> some View {
        VStack(spacing: 12) {
            Image(systemName: tab.systemImage)
                .font(.system(size: 40))
                .foregroundStyle(Color(hexToken: colors.primary))
            Text(tab.titleKey)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color(hexToken: colors.onSurface))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
