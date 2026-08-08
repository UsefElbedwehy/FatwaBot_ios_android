import AzkarFeature
import DesignSystemKit
import DuaFeature
import SwiftUI

/// Azkar and Du'a merged into one screen behind a segmented control (client
/// request, 2026-07-26) — they were previously two separate Worship tiles
/// leading to two separate screens.
///
/// The two libraries keep their own view models and their own push destinations;
/// only the entry point is unified. That keeps the merge a *navigation* change
/// rather than a rewrite of either feature, and means a deep link to either one
/// still lands on the right content — `fatwabot://azkar` and `fatwabot://dua`
/// both open this screen, just on a different segment.
struct RemembranceScreen: View {
    enum Segment: String, CaseIterable, Identifiable {
        case azkar, dua
        var id: String { rawValue }
        var titleKey: LocalizedStringKey {
            switch self {
            case .azkar: return "worship.azkar"
            case .dua: return "worship.dua"
            }
        }
    }

    @State private var segment: Segment
    private let azkarViewModel: AzkarViewModel
    private let duaViewModel: DuaViewModel

    @Environment(\.colorScheme) private var colorScheme
    private var tokens: ColorTokens {
        colorScheme == .dark ? DesignTokens.bundledDefault.dark : DesignTokens.bundledDefault.light
    }

    init(initial: Segment, azkarViewModel: AzkarViewModel, duaViewModel: DuaViewModel) {
        _segment = State(initialValue: initial)
        self.azkarViewModel = azkarViewModel
        self.duaViewModel = duaViewModel
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $segment) {
                ForEach(Segment.allCases) { option in
                    Text(option.titleKey).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .background(Color(hexToken: tokens.surface))

            // Switched rather than kept in a TabView: only the visible library
            // should be loading content and holding list state.
            switch segment {
            case .azkar:
                AzkarBrowseScreen(viewModel: azkarViewModel)
            case .dua:
                DuaLibraryScreen(viewModel: duaViewModel)
            }
        }
        .background(Color(hexToken: tokens.surface))
    }
}
