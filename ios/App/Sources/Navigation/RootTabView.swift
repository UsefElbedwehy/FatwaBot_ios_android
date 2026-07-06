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

struct RootTabView: View {
    @Environment(ThemeStore.self) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @State private var selection: AppTab = .home
    @State private var prayerViewModel = Container.shared.prayerViewModel()

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

            NavigationStack {
                WorshipTabView(prayerViewModel: prayerViewModel)
                    .navigationTitle(Text("tabs.worship"))
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

    private func handleQuickAction(_ action: QuickAction) {
        // M1: qibla lives in Worship; the rest arrive in M2.
        if action == .qibla { selection = .worship }
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
            if let location = prayerViewModel.location {
                NavigationLink {
                    QiblaScreen(location: location, provider: SystemHeadingProvider())
                        .navigationTitle(Text("worship.qibla"))
                } label: {
                    Label("worship.qibla", systemImage: "safari")
                }
            }
            NavigationLink {
                TasbeehScreen(viewModel: Container.shared.tasbeehViewModel())
                    .navigationTitle(Text("worship.tasbeeh"))
                    .navigationBarTitleDisplayMode(.inline)
            } label: {
                Label("worship.tasbeeh", systemImage: "circle.grid.3x3")
            }
            NavigationLink {
                AzkarCategoryListScreen(viewModel: Container.shared.azkarViewModel())
                    .navigationTitle(Text("worship.azkar"))
                    .navigationBarTitleDisplayMode(.inline)
            } label: {
                Label("worship.azkar", systemImage: "book.closed")
            }
            NavigationLink {
                DuaLibraryScreen(viewModel: Container.shared.duaViewModel())
                    .navigationTitle(Text("worship.dua"))
                    .navigationBarTitleDisplayMode(.inline)
            } label: {
                Label("worship.dua", systemImage: "hands.sparkles")
            }
            NavigationLink {
                AwradBoardScreen(viewModel: Container.shared.awradViewModel())
                    .navigationTitle(Text("worship.awrad"))
                    .navigationBarTitleDisplayMode(.inline)
            } label: {
                Label("worship.awrad", systemImage: "leaf")
            }
            NavigationLink {
                HadithCollectionsScreen(viewModel: Container.shared.hadithViewModel())
                    .navigationTitle(Text("worship.hadith"))
                    .navigationBarTitleDisplayMode(.inline)
            } label: {
                Label("worship.hadith", systemImage: "text.book.closed")
            }
        }
    }
}
