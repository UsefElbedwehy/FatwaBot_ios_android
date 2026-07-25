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
                if !ProcessInfo.processInfo.arguments.contains("-skipPermPrompts") {
                    _ = await Container.shared.notificationScheduler().requestAuthorization()
                    await prayerViewModel.start()
                }
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

/// Maroon cradle nav (client mockup, design/homeDesign.jpeg): a full-bleed maroon
/// band with a scooped top edge cradling a raised cream Home button (mihrab logo +
/// "الرئيسية"). A "⋯" (Settings) sits left, a 2×2 grid (Worship) right — white on
/// maroon. Forced LTR so the physical placement matches the mockup in both langs.
private struct FatwaBottomBar: View {
    @Binding var selection: AppTab
    let tokens: ColorTokens

    private let barHeight: CGFloat = 108

    var body: some View {
        ZStack(alignment: .top) {
            NavCradleShape()
                .fill(Color(hexToken: tokens.primary))
                .overlay(
                    NavCradleShape()
                        .stroke(Color.white.opacity(0.16), lineWidth: 2)
                )
                .shadow(color: Color(hexToken: tokens.primary).opacity(0.28), radius: 16, x: 0, y: -4)
                .ignoresSafeArea(edges: .bottom)

            HStack {
                sideItem(.settings, icon: "ellipsis")
                Spacer()
                sideItem(.worship, icon: "square.grid.2x2.fill")
            }
            .padding(.horizontal, 44)
            .frame(height: barHeight)
            .offset(y: 6)

            homeItem
                .frame(maxWidth: .infinity)
                .offset(y: -26)
        }
        .frame(height: barHeight)
        .environment(\.layoutDirection, .leftToRight)
    }

    private func sideItem(_ tab: AppTab, icon: String) -> some View {
        let active = selection == tab
        return Button { selection = tab } label: {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color(hexToken: tokens.onPrimary).opacity(active ? 1 : 0.78))
                .frame(width: 54, height: 54)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.titleKey)
    }

    private var homeItem: some View {
        Button { selection = .home } label: {
            VStack(spacing: 1) {
                Image("LaunchLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30, height: 40)
                Text(AppTab.home.titleKey)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color(hexToken: tokens.primary))
            }
            .frame(width: 92, height: 92)
            .background(
                Circle()
                    .fill(Color(hexToken: tokens.surface))
                    .shadow(color: Color(hexToken: tokens.onSurface).opacity(0.18), radius: 9, x: 0, y: 3)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(AppTab.home.titleKey)
    }
}

/// The maroon nav band: a smooth cradle. Two soft shoulders peak just outside the
/// Home circle, the center dips under it, and the top eases down to the screen
/// edges — sampled from a cosine so every junction (peaks, valley, edges) meets
/// with a horizontal tangent, i.e. no cusps or visible seams.
private struct NavCradleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let top = rect.minY
        let cx = w / 2
        let shoulderHalf: CGFloat = 54   // peaks sit just outside the Home circle
        let valleyDip: CGFloat = 18      // center dips below the shoulder peaks
        let edgeDrop: CGFloat = 22       // screen edges sit below the peaks

        func y(at x: CGFloat) -> CGFloat {
            let d = abs(x - cx)
            if d <= shoulderHalf {
                let t = Double(d / shoulderHalf)              // 0 center → 1 shoulder
                return top + valleyDip * CGFloat(0.5 + 0.5 * cos(.pi * t))
            } else {
                let t = Double((d - shoulderHalf) / (cx - shoulderHalf)) // 0 shoulder → 1 edge
                return top + edgeDrop * CGFloat(0.5 - 0.5 * cos(.pi * t))
            }
        }

        var p = Path()
        p.move(to: CGPoint(x: 0, y: y(at: 0)))
        var x: CGFloat = 0
        while x <= w {
            p.addLine(to: CGPoint(x: x, y: y(at: x)))
            x += 2
        }
        p.addLine(to: CGPoint(x: w, y: y(at: w)))
        p.addLine(to: CGPoint(x: w, y: rect.maxY))
        p.addLine(to: CGPoint(x: 0, y: rect.maxY))
        p.closeSubpath()
        return p
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
