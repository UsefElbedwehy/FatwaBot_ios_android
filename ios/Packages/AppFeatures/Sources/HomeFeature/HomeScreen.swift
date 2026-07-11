import ConfigKit
import CoreKit
import DesignSystemKit
import PrayerKit
import SwiftUI

/// The Home surface: section list from the server layout, native renderers.
/// Feature-specific data (prayer state) is injected by the App composition —
/// HomeFeature does not depend on PrayerFeature (ADR-0010 dependency rule).
public struct HomeScreen: View {
    @State private var viewModel: HomeViewModel
    private let heroContent: HomeHeroContent?
    private let onQuickAction: (QuickAction) -> Void
    @Environment(\.colorScheme) private var colorScheme

    public init(
        viewModel: HomeViewModel,
        heroContent: HomeHeroContent?,
        onQuickAction: @escaping (QuickAction) -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        self.heroContent = heroContent
        self.onQuickAction = onQuickAction
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                ForEach(viewModel.sections, id: \.id) { section in
                    render(section)
                }
            }
            .padding()
        }
        .brandScreenBackground(tokens)
        .task { await viewModel.load() }
        .refreshable { await viewModel.refresh(locales: ["ar", "en"]) }
    }

    private var tokens: ColorTokens {
        let base = DesignTokens.bundledDefault
        return colorScheme == .dark ? base.dark : base.light
    }

    @ViewBuilder
    private func render(_ section: HomeLayout.Section) -> some View {
        switch section.type {
        case "ambient_header":
            AmbientHeaderView(hijri: heroContent?.hijri, locationName: heroContent?.locationName)
        case "prayer_hero":
            if let heroContent {
                PrayerHeroCard(content: heroContent)
            }
        case "ask_ai":
            AskSectionView(enabled: viewModel.askEnabled)
        case "quick_actions":
            QuickActionsGrid(onTap: onQuickAction)
        default:
            EmptyView() // defensively unreachable: load() already filtered
        }
    }
}

/// Prayer state handed to Home by the app composition root.
public struct HomeHeroContent: Equatable {
    public let nextPrayer: PrayerName
    public let nextTime: Date
    public let current: PrayerName?
    public let today: PrayerDay
    public let hijri: HijriDate?
    public let locationName: String?

    public init(
        nextPrayer: PrayerName, nextTime: Date, current: PrayerName?,
        today: PrayerDay, hijri: HijriDate?, locationName: String?
    ) {
        self.nextPrayer = nextPrayer
        self.nextTime = nextTime
        self.current = current
        self.today = today
        self.hijri = hijri
        self.locationName = locationName
    }
}

public enum QuickAction: String, CaseIterable, Identifiable {
    case qibla, tasbeeh, azkar, history

    public var id: String { rawValue }

    var icon: String {
        switch self {
        case .qibla: "safari"
        case .tasbeeh: "circle.grid.3x3"
        case .azkar: "book.closed"
        case .history: "clock.arrow.circlepath"
        }
    }

    var titleKey: LocalizedStringKey {
        switch self {
        case .qibla: "quick.qibla"
        case .tasbeeh: "quick.tasbeeh"
        case .azkar: "quick.azkar"
        case .history: "quick.history"
        }
    }
}
