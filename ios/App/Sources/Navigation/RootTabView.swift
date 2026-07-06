import AwradFeature
import AzkarFeature
import ConfigKit
import DesignSystemKit
import DuaFeature
import Factory
import HadithFeature
import HomeFeature
import PrayerFeature
import PrayerKit
import SwiftUI
import TasbeehFeature

/// Destinations reachable from the Worship tab's own list *and* by deep link
/// from Home's quick actions (task 26 wiring) — pushed onto `worshipPath`.
enum WorshipDestination: Hashable {
    case qibla, tasbeeh, azkar, dua, awrad, hadith
}

struct RootTabView: View {
    @Environment(ThemeStore.self) private var theme
    @Environment(\.colorScheme) private var colorScheme
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
                placeholder(tab: .journey)
                    .navigationTitle(Text("tabs.journey"))
            }
            .tabItem { Label("tabs.journey", systemImage: AppTab.journey.systemImage) }
            .tag(AppTab.journey)

            NavigationStack {
                placeholder(tab: .settings)
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

    private func placeholder(tab: AppTab) -> some View {
        let colors = theme.current(for: colorScheme)
        return VStack(spacing: 12) {
            Image(systemName: tab.systemImage)
                .font(.system(size: 40))
                .foregroundStyle(Color(hexToken: colors.primary))
            Text("common.coming_soon")
                .foregroundStyle(Color(hexToken: colors.onSurfaceSecondary))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hexToken: colors.surface))
    }
}

struct WorshipTabView: View {
    let prayerViewModel: PrayerViewModel

    var body: some View {
        List {
            NavigationLink {
                PrayerScreen(viewModel: prayerViewModel)
                    .navigationTitle(Text("worship.prayer_times"))
            } label: {
                Label("worship.prayer_times", systemImage: "clock")
            }
            if prayerViewModel.location != nil {
                NavigationLink(value: WorshipDestination.qibla) {
                    Label("worship.qibla", systemImage: "safari")
                }
            }
            NavigationLink(value: WorshipDestination.tasbeeh) {
                Label("worship.tasbeeh", systemImage: "circle.grid.3x3")
            }
            NavigationLink(value: WorshipDestination.azkar) {
                Label("worship.azkar", systemImage: "book.closed")
            }
            NavigationLink(value: WorshipDestination.dua) {
                Label("worship.dua", systemImage: "hands.sparkles")
            }
            NavigationLink(value: WorshipDestination.awrad) {
                Label("worship.awrad", systemImage: "leaf")
            }
            NavigationLink(value: WorshipDestination.hadith) {
                Label("worship.hadith", systemImage: "text.book.closed")
            }
        }
    }
}
