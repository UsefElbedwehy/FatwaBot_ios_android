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
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if viewModel.categories.isEmpty {
                    if viewModel.isLoadingCategories {
                        loadingState
                    } else {
                        emptyState
                    }
                } else {
                    // No section header: this list is now hosted under a segmented
                    // control already labelled "الأذكار", so a header here just
                    // repeated it (merged Azkar/Du'a screen, 2026-07-26).
                    VStack(spacing: 12) {
                        ForEach(viewModel.categories) { category in
                            NavigationLink {
                                AzkarSessionScreen(viewModel: viewModel, category: category)
                            } label: {
                                row(for: category)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(20)
        }
        .brandScreenBackground(tokens)
        .motionAnimation(.easeInOut(duration: MotionTokens.standardDuration), value: viewModel.categories.isEmpty)
        .task { await viewModel.loadCategories(locale: locale) }
    }

    private func row(for category: AzkarCategory) -> some View {
        let done = viewModel.isCompletedToday(category.id)
        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(done
                          ? Color(hexToken: tokens.primary).opacity(0.14)
                          : Color(hexToken: tokens.primaryContainer))
                Image(systemName: done ? "checkmark.seal.fill" : "book.closed")
                    .font(.title3)
                    .foregroundStyle(Color(hexToken: tokens.primary))
            }
            .frame(width: 46, height: 46)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(category.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color(hexToken: tokens.onSurface))
                Text("\(category.items.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
            }

            Spacer(minLength: 8)

            if done {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color(hexToken: tokens.primary))
                    .accessibilityLabel(Text("azkar.completed_today_a11y"))
            } else {
                Image(systemName: "chevron.forward")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary).opacity(0.7))
                    .accessibilityHidden(true)
            }
        }
        .brandCard(tokens)
        .accessibilityElement(children: .combine)
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(Color(hexToken: tokens.primary))
            Text("azkar.loading")
                .font(.subheadline)
                .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var emptyState: some View {
        BrandEmptyState(
            systemImage: "book.closed",
            messageKey: "azkar.empty_state",
            tokens: tokens
        )
    }
}
