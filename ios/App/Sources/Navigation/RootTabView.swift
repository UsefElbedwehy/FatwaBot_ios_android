import AwradFeature
import AzkarFeature
import ConfigKit
import DesignSystemKit
import DuaFeature
import Factory
import GamificationFeature
import HadithFeature
import LeaderboardFeature
import PrayerFeature
import PrayerKit
import SearchHistoryFeature
import SwiftUI
import TasbeehFeature

/// Destinations reachable from the Worship tab's own list *and* by deep link
/// from Home's quick actions (task 26 wiring) — pushed onto `worshipPath`.
enum WorshipDestination: Hashable {
    case qibla, tasbeeh, azkar, dua, awrad, hadith, journey
}

struct RootTabView: View {
    @State private var selection: AppTab = .home
    @State private var prayerViewModel = Container.shared.prayerViewModel()
    @State private var worshipPath = NavigationPath()
    // Hoisted so they're created ONCE and survive tab switches. Previously
    // built inline in `body` (recreated on every re-eval → the Journey tab
    // reset to an empty profile and re-ran a full network reload on every
    // visit, which is the lag). Mirrors `prayerViewModel` above.
    @State private var gamificationViewModel = Container.shared.gamificationViewModel()
    @State private var leaderboardViewModel = Container.shared.leaderboardViewModel()
    @State private var searchHistoryViewModel = Container.shared.searchHistoryViewModel()

    @Environment(\.colorScheme) private var colorScheme
    private var tokens: ColorTokens {
        colorScheme == .dark ? DesignTokens.bundledDefault.dark : DesignTokens.bundledDefault.light
    }

    var body: some View {
        Group { content }
            .safeAreaInset(edge: .bottom) {
                FatwaBottomBar(selection: $selection, tokens: tokens)
            }
            .task {
                _ = await Container.shared.notificationScheduler().requestAuthorization()
                await prayerViewModel.start()
                await Container.shared.configService().refresh(locales: ["ar", "en"])
            }
    }

    @ViewBuilder
    private var content: some View {
        switch selection {
        case .home:
            SearchHomeScreen()
        case .worship:
            NavigationStack(path: $worshipPath) {
                WorshipTabView(prayerViewModel: prayerViewModel)
                    .navigationTitle(Text("tabs.worship"))
                    .navigationDestination(for: WorshipDestination.self) { destination in
                        worshipDestinationView(destination)
                    }
            }
        case .settings:
            NavigationStack {
                SettingsScreen(prayerViewModel: prayerViewModel)
                    .navigationTitle(Text("tabs.settings"))
            }
        }
    }

    @ViewBuilder
    private func worshipDestinationView(_ destination: WorshipDestination) -> some View {
        switch destination {
        case .qibla:
            if let location = prayerViewModel.location {
                QiblaScreen(location: location, provider: SystemHeadingProvider())
                    .navigationTitle(Text("worship.qibla"))
            }
        case .tasbeeh:
            TasbeehScreen(viewModel: Container.shared.tasbeehViewModel())
                .navigationTitle(Text("worship.tasbeeh"))
                .navigationBarTitleDisplayMode(.inline)
        case .azkar:
            AzkarCategoryListScreen(viewModel: Container.shared.azkarViewModel())
                .navigationTitle(Text("worship.azkar"))
                .navigationBarTitleDisplayMode(.inline)
        case .dua:
            DuaLibraryScreen(viewModel: Container.shared.duaViewModel())
                .navigationTitle(Text("worship.dua"))
                .navigationBarTitleDisplayMode(.inline)
        case .awrad:
            AwradBoardScreen(viewModel: Container.shared.awradViewModel())
                .navigationTitle(Text("worship.awrad"))
                .navigationBarTitleDisplayMode(.inline)
        case .hadith:
            HadithCollectionsScreen(viewModel: Container.shared.hadithViewModel())
                .navigationTitle(Text("worship.hadith"))
                .navigationBarTitleDisplayMode(.inline)
        case .journey:
            GamificationScreen(viewModel: gamificationViewModel)
                .navigationTitle(Text("tabs.journey"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        NavigationLink { LeaderboardScreen(viewModel: leaderboardViewModel) } label: {
                            Label("leaderboard.title", systemImage: "trophy")
                        }
                    }
                    ToolbarItem(placement: .secondaryAction) {
                        NavigationLink { SearchHistoryScreen(viewModel: searchHistoryViewModel) } label: {
                            Label("search_history.title", systemImage: "clock.arrow.circlepath")
                        }
                    }
                }
        }
    }

}

/// Custom floating bottom bar (client redesign): Worship (left) · Home (center,
/// raised) · Settings (right). Journey moved into the Worship grid. Forced LTR so
/// the physical placement matches the mockup in both languages.
private struct FatwaBottomBar: View {
    @Binding var selection: AppTab
    let tokens: ColorTokens

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            sideItem(.worship, icon: "square.grid.2x2.fill")
            homeItem
            sideItem(.settings, icon: "gearshape.fill")
        }
        .padding(.horizontal, 22)
        .padding(.top, 12)
        .padding(.bottom, 6)
        .background(
            Color(hexToken: tokens.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .shadow(color: Color(hexToken: tokens.primary).opacity(0.14), radius: 18, x: 0, y: 2)
        )
        .padding(.horizontal, 16)
        .environment(\.layoutDirection, .leftToRight)
    }

    private func sideItem(_ tab: AppTab, icon: String) -> some View {
        let active = selection == tab
        return Button { selection = tab } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                Text(tab.titleKey)
                    .font(.caption2.weight(.medium))
            }
            .foregroundStyle(active ? Color(hexToken: tokens.primary) : Color(hexToken: tokens.onSurfaceSecondary))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var homeItem: some View {
        let active = selection == .home
        return Button { selection = .home } label: {
            VStack(spacing: 5) {
                ZStack {
                    Circle()
                        .fill(Color(hexToken: tokens.surfaceElevated))
                        .frame(width: 60, height: 60)
                        .overlay(Circle().stroke(Color(hexToken: tokens.primary).opacity(0.14), lineWidth: 1))
                        .shadow(color: Color(hexToken: tokens.primary).opacity(0.22), radius: 8, x: 0, y: 3)
                    Image("LaunchLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 26, height: 34)
                }
                Text(AppTab.home.titleKey)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(active ? Color(hexToken: tokens.primary) : Color(hexToken: tokens.onSurfaceSecondary))
            }
            .frame(maxWidth: .infinity)
            .offset(y: -14)
        }
        .buttonStyle(.plain)
    }
}

struct WorshipTabView: View {
    let prayerViewModel: PrayerViewModel
    @Environment(\.colorScheme) private var colorScheme

    private var tokens: ColorTokens {
        colorScheme == .dark ? DesignTokens.bundledDefault.dark : DesignTokens.bundledDefault.light
    }

    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                NavigationLink {
                    PrayerScreen(viewModel: prayerViewModel)
                        .navigationTitle(Text("worship.prayer_times"))
                } label: {
                    WorshipTile(icon: "clock.fill", titleKey: "worship.prayer_times", tokens: tokens)
                }
                if prayerViewModel.location != nil {
                    NavigationLink(value: WorshipDestination.qibla) {
                        WorshipTile(icon: "safari.fill", titleKey: "worship.qibla", tokens: tokens)
                    }
                }
                NavigationLink(value: WorshipDestination.tasbeeh) {
                    WorshipTile(icon: "circle.grid.3x3.fill", titleKey: "worship.tasbeeh", tokens: tokens)
                }
                NavigationLink(value: WorshipDestination.azkar) {
                    WorshipTile(icon: "book.closed.fill", titleKey: "worship.azkar", tokens: tokens)
                }
                NavigationLink(value: WorshipDestination.dua) {
                    WorshipTile(icon: "hands.sparkles.fill", titleKey: "worship.dua", tokens: tokens)
                }
                NavigationLink(value: WorshipDestination.awrad) {
                    WorshipTile(icon: "leaf.fill", titleKey: "worship.awrad", tokens: tokens)
                }
                NavigationLink(value: WorshipDestination.hadith) {
                    WorshipTile(icon: "text.book.closed.fill", titleKey: "worship.hadith", tokens: tokens)
                }
                NavigationLink(value: WorshipDestination.journey) {
                    WorshipTile(icon: "chart.line.uptrend.xyaxis", titleKey: "tabs.journey", tokens: tokens)
                }
            }
            .padding(16)
        }
        .background(Color(hexToken: tokens.surface))
    }
}

private struct WorshipTile: View {
    let icon: String
    let titleKey: LocalizedStringKey
    let tokens: ColorTokens

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(hexToken: tokens.primaryContainer))
                Image(systemName: icon)
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(Color(hexToken: tokens.primary))
            }
            .frame(height: 88)
            .accessibilityHidden(true)
            Text(titleKey)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color(hexToken: tokens.onSurface))
                .multilineTextAlignment(.center)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color(hexToken: tokens.surfaceElevated), in: RoundedRectangle(cornerRadius: 20))
    }
}
