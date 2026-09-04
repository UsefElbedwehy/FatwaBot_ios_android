import AwradFeature
import AzkarFeature
import ConfigKit
import CoreKit
import DesignSystemKit
import DuaFeature
import Factory
import FatwaSearchFeature
import GamificationFeature
import HadithFeature
import LeaderboardFeature
import PrayerFeature
import PrayerKit
import SearchHistoryFeature
import SwiftUI
import TasbeehFeature

/// A single destination: which mode, and any text the search bar already had
/// typed into it (empty for the three intent cards).
enum FatwaSearchDestination: Hashable {
    case ask(mode: FatwaSearchMode, initialQuestion: String)
}

/// Destinations reachable from the Worship tab's own list *and* by deep link
/// from Home's quick actions (task 26 wiring) — pushed onto `worshipPath`.
enum WorshipDestination: Hashable {
    case qibla, tasbeeh, azkar, dua, awrad, hadith, journey
}

extension WorshipDestination {
    /// Stable, non-PII analytics key. Kept identical to Android's `screenKey`
    /// mapping so one dashboard serves both platforms.
    var analyticsScreenKey: String {
        switch self {
        case .qibla: return AnalyticsEvents.screenQibla
        case .tasbeeh: return AnalyticsEvents.screenTasbeeh
        case .azkar: return AnalyticsEvents.screenAzkar
        case .dua: return AnalyticsEvents.screenDua
        case .awrad: return AnalyticsEvents.screenAwrad
        case .hadith: return AnalyticsEvents.screenHadith
        case .journey: return AnalyticsEvents.screenJourney
        }
    }
}

extension DeepLink {
    /// The worship-stack destination this link pushes, if any. `home`/`prayer`
    /// resolve to a tab root instead and so have none.
    var worshipDestination: WorshipDestination? {
        switch self {
        case .qibla: return .qibla
        case .tasbeeh: return .tasbeeh
        case .azkar: return .azkar
        case .dua: return .dua
        case .awrad: return .awrad
        case .hadith: return .hadith
        case .journey: return .journey
        case .home, .prayer: return nil
        }
    }
}

/// Clearance for the custom bottom bar.
///
/// The root `.safeAreaInset` reserves the bar's height, and that works for
/// content placed directly in it (the Home tab). It does NOT reach scroll views
/// hosted inside a `NavigationStack` — verified on device: Settings scrolled to
/// the end left its whole About section behind the band. So every screen the
/// stacks host gets the inset applied directly, where it does take effect.
///
/// Applied here in RootTabView rather than in each feature screen: the bar is
/// this file's concern, and a feature module has no business knowing its height.
private extension View {
    func bottomBarClearance() -> some View {
        safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: FatwaBottomBar.visualHeight)
        }
    }
}

struct RootTabView: View {
    @State private var selection: AppTab = .home
    @State private var prayerViewModel = Container.shared.prayerViewModel()
    // Typed rather than `NavigationPath` so the screen on top is readable
    // (NavigationPath is opaque) — needed for screen-view reporting.
    @State private var worshipPath: [WorshipDestination] = []
    // Home's own stack — pushed by a Search-Home intent card or the search
    // field, mirrors worshipPath's typed-array approach.
    @State private var homePath: [FatwaSearchDestination] = []
    // Which specific azkar/hadith item to land on — set only when the tap
    // that opened this path was a content-reminder notification.
    @State private var worshipContentFocus: ContentFocus?
    // Hoisted so they're created ONCE and survive tab switches. Previously
    // built inline in `body` (recreated on every re-eval → the Journey tab
    // reset to an empty profile and re-ran a full network reload on every
    // visit, which is the lag). Mirrors `prayerViewModel` above.
    @State private var gamificationViewModel = Container.shared.gamificationViewModel()
    @State private var leaderboardViewModel = Container.shared.leaderboardViewModel()
    @State private var searchHistoryViewModel = Container.shared.searchHistoryViewModel()
    // Hoisted like the others: the merged Azkar/Du'a screen switches between
    // them, and recreating a view model on every segment flip would re-run its
    // content load.
    @State private var azkarViewModel = Container.shared.azkarViewModel()
    @State private var duaViewModel = Container.shared.duaViewModel()
    private let analytics = Container.shared.analyticsTracking()
    /// Notification taps arrive here rather than through `.onOpenURL` — a tap is
    /// not a URL open, so the delegate has to hand the link over in-process.
    private let tapRouter = NotificationTapRouter.shared

    @Environment(\.colorScheme) private var colorScheme
    private var tokens: ColorTokens {
        colorScheme == .dark ? DesignTokens.bundledDefault.dark : DesignTokens.bundledDefault.light
    }

    /// True once a worship or home destination is pushed. The bar is a
    /// *tab-root* control: on a pushed screen you navigate with Back, not by
    /// switching tabs, so 140pt of maroon band would only crowd content that
    /// wants the room (the Tasbeeh tap target, the Qibla compass, a hadith
    /// being read, or here, the search answer + citations).
    private var isShowingDetail: Bool {
        (selection == .worship && !worshipPath.isEmpty) || (selection == .home && !homePath.isEmpty)
    }

    var body: some View {
        Group { content }
            .safeAreaInset(edge: .bottom) {
                // Conditional inside the inset, so hiding the bar also releases
                // the space it reserved — no empty gap left behind.
                if !isShowingDetail {
                    FatwaBottomBar(selection: $selection, tokens: tokens)
                        .transition(.move(edge: .bottom))
                }
            }
            .animation(.easeInOut(duration: 0.22), value: isShowingDetail)
            .task {
                if !ProcessInfo.processInfo.arguments.contains("-skipPermPrompts") {
                    _ = await Container.shared.notificationScheduler().requestAuthorization()
                    await prayerViewModel.start()
                    // After the prayer schedule, so the two never race for the
                    // 64 pending slots. Safe to run on every launch: the plan is
                    // seeded by the day, so re-registering is a no-op.
                    await Container.shared.contentReminderScheduler().reschedule(
                        preferences: Container.shared.contentReminderPreferenceStore().load(),
                        now: Date()
                    )
                    // Last of the three, on the slice the other two left free.
                    // Re-registering is a no-op: the ids are derived from the wird
                    // ids and the triggers repeat daily at a fixed time.
                    await Container.shared.wirdReminderScheduler().reschedule(
                        preferences: Container.shared.wirdReminderPreferenceStore().load(),
                        wirds: Container.shared.wirdStore().loadWirds(),
                        // Supplied so a wird anchored to Fajr follows the actual
                        // prayer rather than falling back to a clock time.
                        // Resolved here, on the main actor, rather than inside
                        // the closure. `MainActor.assumeIsolated` traps when the
                        // closure is invoked from the planner's async context —
                        // it crashed the app the moment the switch was tapped.
                        prayerTime: WirdAnchorTimes.lookup(from: prayerViewModel)
                    )
                }
                await Container.shared.configService().refresh(locales: ["ar", "en"])
            }
            .onChange(of: tapRouter.pendingLink) { _, link in
                guard let link else { return }
                analytics.event(
                    AnalyticsEvents.notificationOpenedApp,
                    params: [AnalyticsEvents.paramRoute: link.rawValue]
                )
                open(link, contentFocus: tapRouter.pendingContentFocus)
                tapRouter.consume()
            }
            .onOpenURL { url in
                guard let link = DeepLink(url: url) else { return }
                // Which widget routes actually get tapped — the one signal that
                // says whether the widgets earn their home-screen slot.
                analytics.event(
                    AnalyticsEvents.widgetOpenedApp,
                    params: [AnalyticsEvents.paramRoute: link.rawValue]
                )
                open(link)
            }
            // Reported from ONE place, rather than an .onAppear per screen —
            // those drift as screens are added and quietly stop firing, and
            // nothing fails loudly when they do.
            .onChange(of: currentScreenKey, initial: true) { _, key in
                analytics.screenView(key)
            }
    }

    /// Advisory note for the Tasbeeh screen. Server-provided (ADR-0011) so it can
    /// be edited without a release; falls back to the bundled placeholder when the
    /// server hasn't supplied one, and to nothing if an operator blanks it
    /// deliberately.
    private var tasbeehNotice: String? {
        let locale = ContentLocale.current
        if let remote = Container.shared.configService().string("tasbeeh.notice", locale: locale) {
            return remote.isEmpty ? nil : remote
        }
        return String(localized: "tasbeeh.notice")
    }

    /// Contact channels for the Settings screen. Server-provided (ADR-0011) so an
    /// operator can change an address — or switch a channel off by blanking it —
    /// without a release. Resolved here rather than in the screen so nothing
    /// below the composition root learns about config (ADR-0010).
    ///
    /// Nothing is bundled as a fallback on purpose: until the dashboard supplies
    /// a value the row is hidden, because a made-up address ships worse than no
    /// address at all.
    private var contactLinks: ContactLinks {
        let locale = ContentLocale.current
        let config = Container.shared.configService()
        func value(_ key: String) -> String? {
            let trimmed = (config.string(key, locale: locale) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return ContactLinks(
            email: value("contact.email"),
            whatsapp: value("contact.whatsapp"),
            instagram: value("contact.instagram"),
            x: value("contact.x")
        )
    }

    /// Stable, non-PII screen key. A pushed worship destination wins over the
    /// tab, since that's the screen actually on top.
    private var currentScreenKey: String {
        switch selection {
        case .home:
            return homePath.isEmpty ? AnalyticsEvents.screenHome : AnalyticsEvents.screenFatwaSearch
        case .settings: return AnalyticsEvents.screenSettings
        case .worship:
            guard let destination = worshipPath.last else {
                return AnalyticsEvents.screenWorship
            }
            return destination.analyticsScreenKey
        }
    }

    /// Routes a widget / Live Activity / notification tap to the screen it
    /// promised. Resets the worship stack first so a second tap from a
    /// different source doesn't land on top of the previous destination.
    ///
    /// - Parameter contentFocus: which specific azkar/hadith item to land on,
    ///   for a content-reminder tap. `nil` for every other source (widgets and
    ///   Live Activities have never known about a specific item, only a tab).
    private func open(_ link: DeepLink, contentFocus: ContentFocus? = nil) {
        switch link {
        case .home:
            selection = .home
            homePath = []
        case .prayer:
            // Prayer is a NavigationLink inside the grid rather than a
            // `WorshipDestination`, so land on the Worship root; the prayer
            // hero is the first thing there.
            selection = .worship
            worshipPath = []
        case .qibla, .tasbeeh, .azkar, .dua, .awrad, .hadith, .journey:
            selection = .worship
            worshipPath = link.worshipDestination.map { [$0] } ?? []
            worshipContentFocus = contentFocus
        }
    }

    @ViewBuilder
    private var content: some View {
        switch selection {
        case .home:
            NavigationStack(path: $homePath) {
                SearchHomeScreen(onOpen: { mode in homePath.append(.ask(mode: mode, initialQuestion: "")) })
                    .bottomBarClearance()
                    .navigationDestination(for: FatwaSearchDestination.self) { destination in
                        switch destination {
                        case .ask(let mode, let initialQuestion):
                            // No clearance here: the bar hides on push, matching
                            // the worship stack's pattern immediately below.
                            FatwaSearchScreen(
                                viewModel: Container.shared.fatwaSearchViewModel((mode: mode, initialQuestion: initialQuestion))
                            )
                        }
                    }
            }
        case .worship:
            NavigationStack(path: $worshipPath) {
                WorshipTabView(prayerViewModel: prayerViewModel)
                    .bottomBarClearance()
                    .navigationTitle(Text("tabs.worship"))
                    .navigationDestination(for: WorshipDestination.self) { destination in
                        // No clearance here: the bar hides on push, so reserving
                        // space for it would leave a dead gap at the bottom.
                        worshipDestinationView(destination)
                    }
            }
        case .settings:
            NavigationStack {
                SettingsScreen(prayerViewModel: prayerViewModel, contact: contactLinks)
                    .bottomBarClearance()
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
            TasbeehScreen(viewModel: Container.shared.tasbeehViewModel(), notice: tasbeehNotice)
                .navigationTitle(Text("worship.tasbeeh"))
                .navigationBarTitleDisplayMode(.inline)
        case .azkar, .dua:
            // One screen, two segments. The destination only decides which
            // segment opens, so existing deep links keep working unchanged.
            RemembranceScreen(
                initial: destination == .dua ? .dua : .azkar,
                azkarViewModel: azkarViewModel,
                duaViewModel: duaViewModel,
                focus: worshipContentFocus
            )
            .navigationTitle(Text("worship.remembrance"))
            .navigationBarTitleDisplayMode(.inline)
        case .awrad:
            AwradBoardScreen(viewModel: Container.shared.awradViewModel())
                .navigationTitle(Text("worship.wird_daily"))
                .navigationBarTitleDisplayMode(.inline)
        case .hadith:
            HadithCollectionsScreen(
                viewModel: Container.shared.hadithViewModel(),
                locale: ContentLocale.current,
                focusEntryID: worshipContentFocus?.contentID,
                focusCollectionSlug: worshipContentFocus?.categorySlug
            )
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
    /// Band + the circle's overhang. The single source of truth for how much
    /// vertical space the bar actually occupies, used both to lay the bar out
    /// and to keep screen content clear of it.
    static let visualHeight: CGFloat = 140

    @Binding var selection: AppTab
    let tokens: ColorTokens
    @Environment(\.colorScheme) private var colorScheme

    private let barHeight: CGFloat = 108
    /// How far the Home circle rises above the band.
    private let homeLift: CGFloat = 26
    /// Reserved space ABOVE the band. `safeAreaInset` insets content by this
    /// view's declared height, but the Home circle is drawn on an offset — i.e.
    /// outside that height — so without this the bar visually occupies ~134pt
    /// while only 108 is reserved, and content scrolls under the circle. Adding
    /// it here fixes every screen at once; padding each screen individually
    /// would mean remembering the number forever.
    private var overhang: CGFloat { homeLift + 6 } // +6 clears the circle's shadow

    var body: some View {
        ZStack(alignment: .top) {
            NavCradleShape()
                .fill(Color(hexToken: tokens.primary))
                // `primary` is lifted in the dark palette so it can serve as a
                // foreground on the near-black surface. At the size of this band
                // that lift reads as pink rather than as the brand maroon, so
                // knock it back with an opaque dark wash — the band is a brand
                // *surface*, and wants the deep tone the light theme uses.
                .overlay(
                    NavCradleShape()
                        .fill(Color.black.opacity(colorScheme == .dark ? 0.42 : 0))
                )
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
                .offset(y: -homeLift)
        }
        .frame(height: barHeight)
        // Reserve the circle's overhang so content never slides beneath it.
        .padding(.top, overhang)
        .environment(\.layoutDirection, .leftToRight)
    }

    private func sideItem(_ tab: AppTab, icon: String) -> some View {
        let active = selection == tab
        return Button { selection = tab } label: {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color(hexToken: tokens.onPrimary).opacity(active ? 1 : 0.78))
                .frame(width: 60, height: 60)
                // Without this SwiftUI hit-tests the *rendered glyph*, not the
                // frame — so `ellipsis` was three small dots' worth of target
                // while the grid icon beside it was a solid block. That is why
                // one felt broken and the other did not.
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.titleKey)
    }

    private var homeItem: some View {
        Button { selection = .home } label: {
            VStack(spacing: 1) {
                // FatwaMark tints the raw raster explicitly rather than relying on
                // its baked-in color, which isn't a brand token and reads poorly
                // outside a light circle — see SearchHomeScreen for the same fix.
                FatwaMark(color: Color(hexToken: tokens.primary))
                    .frame(width: 30, height: 40)
                Text(AppTab.home.titleKey)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color(hexToken: tokens.primary))
            }
            .frame(width: 92, height: 92)
            .background(
                Circle()
                    .fill(Color(hexToken: colorScheme == .dark ? tokens.onSurface : tokens.surface))
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
                // Wird and Tasbeeh swapped grid places at the owner's request —
                // no change to what either does, just where they sit.
                NavigationLink(value: WorshipDestination.awrad) {
                    WorshipTile(icon: "leaf.fill", titleKey: "worship.wird_tile", tokens: tokens)
                }
                // Azkar + Du'a share one tile now; the screen behind it segments.
                NavigationLink(value: WorshipDestination.azkar) {
                    WorshipTile(icon: "book.closed.fill", titleKey: "worship.remembrance", tokens: tokens)
                }
                NavigationLink(value: WorshipDestination.tasbeeh) {
                    WorshipTile(icon: "circle.grid.3x3.fill", titleKey: "worship.tasbeeh", tokens: tokens)
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
