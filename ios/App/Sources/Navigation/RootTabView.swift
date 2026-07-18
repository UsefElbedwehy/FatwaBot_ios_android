import AwradFeature
import AzkarFeature
import ConfigKit
import DesignSystemKit
import DuaFeature
import Factory
import GamificationFeature
import HadithFeature
import HomeFeature
import LeaderboardFeature
import PrayerFeature
import PrayerKit
import SearchHistoryFeature
import SwiftUI
import TasbeehFeature

/// Destinations reachable from the Worship tab's own list *and* by deep link
/// from Home's quick actions (task 26 wiring) — pushed onto `worshipPath`.
enum WorshipDestination: Hashable {
    case qibla, tasbeeh, azkar, dua, awrad, hadith
}

struct RootTabView: View {
    @State private var selection: AppTab = .home
    @State private var prayerViewModel = Container.shared.prayerViewModel()
    @State private var worshipPath = NavigationPath()

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack {
                HomeScreen(
                    viewModel: HomeViewModel(
                        config: Container.shared.configService(),
                        appVersion: AppEnvironment.appVersion
                    ),
                    heroContent: heroContent,
                    onQuickAction: handleQuickAction
                )
                .navigationTitle(Text("tabs.home"))
                .navigationBarTitleDisplayMode(.inline)
                .task {
                    _ = await Container.shared.notificationScheduler().requestAuthorization()
                    await prayerViewModel.start()
                    await Container.shared.configService().refresh(locales: ["ar", "en"])
                }
            }
            .tabItem { Label("tabs.home", systemImage: AppTab.home.systemImage) }
            .tag(AppTab.home)

            NavigationStack(path: $worshipPath) {
                WorshipTabView(prayerViewModel: prayerViewModel)
                    .navigationTitle(Text("tabs.worship"))
                    .navigationDestination(for: WorshipDestination.self) { destination in
                        worshipDestinationView(destination)
                    }
            }
            .tabItem { Label("tabs.worship", systemImage: AppTab.worship.systemImage) }
            .tag(AppTab.worship)

            NavigationStack {
                GamificationScreen(viewModel: Container.shared.gamificationViewModel())
                    .navigationTitle(Text("tabs.journey"))
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            NavigationLink {
                                LeaderboardScreen(viewModel: Container.shared.leaderboardViewModel())
                            } label: {
                                Label("leaderboard.title", systemImage: "trophy")
                            }
                        }
                        ToolbarItem(placement: .secondaryAction) {
                            NavigationLink {
                                SearchHistoryScreen(viewModel: Container.shared.searchHistoryViewModel())
                            } label: {
                                Label("search_history.title", systemImage: "clock.arrow.circlepath")
                            }
                        }
                    }
            }
            .tabItem { Label("tabs.journey", systemImage: AppTab.journey.systemImage) }
            .tag(AppTab.journey)

            NavigationStack {
                SettingsScreen(prayerViewModel: prayerViewModel)
                    .navigationTitle(Text("tabs.settings"))
            }
            .tabItem { Label("tabs.settings", systemImage: AppTab.settings.systemImage) }
            .tag(AppTab.settings)
        }
    }

    private var heroContent: HomeHeroContent? {
        guard let next = prayerViewModel.nextPrayer, let today = prayerViewModel.today else { return nil }
        return HomeHeroContent(
            nextPrayer: next.next,
            nextTime: next.nextTime,
            current: next.current,
            today: today,
            hijri: prayerViewModel.hijri,
            locationName: prayerViewModel.location?.name
        )
    }

    /// Deep-links from Home's quick actions (task 26): switches to Worship and
    /// pushes the target screen directly — no extra tap required. `.history`
    /// (Search History) has no content until AI Search ships (M5+), so it is
    /// intentionally inert rather than routing to a hollow screen.
    private func handleQuickAction(_ action: QuickAction) {
        switch action {
        case .qibla:
            guard prayerViewModel.location != nil else { selection = .worship; return }
            worshipPath.append(WorshipDestination.qibla)
        case .tasbeeh:
            worshipPath.append(WorshipDestination.tasbeeh)
        case .azkar:
            worshipPath.append(WorshipDestination.azkar)
        case .history:
            return
        }
        selection = .worship
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
        }
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
