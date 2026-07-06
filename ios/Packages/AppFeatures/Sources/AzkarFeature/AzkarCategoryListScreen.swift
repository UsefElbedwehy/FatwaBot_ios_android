import ContentKit
import DesignSystemKit
import SwiftUI

/// Category browser (docs/features/azkar.md screen 1). Loads from ContentKit
/// (cache → bundled seed, offline-first) and shows today's completion badge.
public struct AzkarCategoryListScreen: View {
    @State private var viewModel: AzkarViewModel
    @Environment(\.colorScheme) private var colorScheme
    private let locale: String

    public init(viewModel: AzkarViewModel, locale: String = "ar") {
        _viewModel = State(initialValue: viewModel)
        self.locale = locale
    }

    private var tokens: ColorTokens {
        colorScheme == .dark ? DesignTokens.bundledDefault.dark : DesignTokens.bundledDefault.light
    }

    public var body: some View {
        Group {
            if viewModel.categories.isEmpty {
                emptyState
            } else {
                List(viewModel.categories) { category in
                    NavigationLink {
                        AzkarSessionScreen(viewModel: viewModel, category: category)
                    } label: {
                        row(for: category)
                    }
                }
            }
        }
        .task { await viewModel.loadCategories(locale: locale) }
    }

    private func row(for category: AzkarCategory) -> some View {
        HStack {
            Text(category.name)
            Spacer()
            if viewModel.isCompletedToday(category.id) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color(hexToken: tokens.primary))
                    .accessibilityLabel(Text("azkar.completed_today_a11y"))
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            ProgressView()
            Text("azkar.loading")
                .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
