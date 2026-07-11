import ContentKit
import DesignSystemKit
import SwiftUI

/// Library browse/search home (docs/features/dua.md screen 1).
public struct DuaLibraryScreen: View {
    @State private var viewModel: DuaViewModel
    @Environment(\.colorScheme) private var colorScheme
    private let locale: String

    public init(viewModel: DuaViewModel, locale: String = "ar") {
        _viewModel = State(initialValue: viewModel)
        self.locale = locale
    }

    private var tokens: ColorTokens {
        colorScheme == .dark ? DesignTokens.bundledDefault.dark : DesignTokens.bundledDefault.light
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                searchField

                if let results = viewModel.searchResults {
                    searchResultsSection(results)
                } else {
                    if !viewModel.favoriteDuas.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            BrandSectionHeader("dua.favorites", systemImage: "heart.fill", tokens: tokens)
                            VStack(spacing: 12) {
                                ForEach(viewModel.favoriteDuas) { dua in
                                    NavigationLink {
                                        DuaReadingScreen(viewModel: viewModel, dua: dua)
                                    } label: {
                                        DuaRowCard(dua: dua, isFavorite: true, tokens: tokens)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    ForEach(viewModel.categories) { category in
                        VStack(alignment: .leading, spacing: 12) {
                            CategorySectionHeader(title: category.name, tokens: tokens)
                            VStack(spacing: 12) {
                                ForEach(category.duas) { dua in
                                    NavigationLink {
                                        DuaReadingScreen(viewModel: viewModel, dua: dua)
                                    } label: {
                                        DuaRowCard(dua: dua, isFavorite: viewModel.isFavorite(dua.id), tokens: tokens)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    if viewModel.categories.isEmpty && viewModel.favoriteDuas.isEmpty {
                        if viewModel.isLoadingCategories {
                            HStack {
                                Spacer()
                                ProgressView().tint(Color(hexToken: tokens.primary))
                                Spacer()
                            }
                            .padding(.vertical, 44)
                        } else {
                            BrandEmptyState(
                                systemImage: "hands.sparkles",
                                messageKey: "dua.empty_state",
                                tokens: tokens
                            )
                        }
                    }
                }
            }
            .padding(20)
        }
        .brandScreenBackground(tokens)
        .task { await viewModel.loadCategories(locale: locale) }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color(hexToken: tokens.primary))
            TextField("dua.search_placeholder", text: $viewModel.searchQuery)
                .foregroundStyle(Color(hexToken: tokens.onSurface))
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(hexToken: tokens.surfaceElevated), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(hexToken: tokens.outline).opacity(0.6), lineWidth: 1)
        )
        .shadow(color: Color(hexToken: tokens.primary).opacity(0.05), radius: 8, x: 0, y: 4)
    }

    @ViewBuilder
    private func searchResultsSection(_ results: [Dua]) -> some View {
        if results.isEmpty {
            BrandEmptyState(
                systemImage: "magnifyingglass",
                messageKey: "dua.search_no_results",
                tokens: tokens
            )
        } else {
            VStack(alignment: .leading, spacing: 12) {
                BrandSectionHeader("dua.search_results", systemImage: "text.magnifyingglass", tokens: tokens)
                VStack(spacing: 12) {
                    ForEach(results) { dua in
                        NavigationLink {
                            DuaReadingScreen(viewModel: viewModel, dua: dua)
                        } label: {
                            DuaRowCard(dua: dua, isFavorite: viewModel.isFavorite(dua.id), tokens: tokens)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

/// Section header for a server-provided (already-localized) category name.
/// Mirrors `BrandSectionHeader`'s look but accepts a dynamic `String` so the
/// content isn't misinterpreted as a localization key.
private struct CategorySectionHeader: View {
    let title: String
    let tokens: ColorTokens

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(
                    LinearGradient(
                        colors: [Color(hexToken: tokens.primary), Color(hexToken: tokens.accent)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(width: 4, height: 18)
            Text(verbatim: title)
                .font(.title3.weight(.bold))
                .foregroundStyle(Color(hexToken: tokens.onSurface))
            Spacer(minLength: 8)
        }
        .accessibilityAddTraits(.isHeader)
    }
}

/// A tappable premium card for one dua: title, optional source preview, and a
/// favorite indicator + chevron affordance.
private struct DuaRowCard: View {
    let dua: Dua
    let isFavorite: Bool
    let tokens: ColorTokens

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle().fill(Color(hexToken: tokens.primaryContainer))
                Image(systemName: isFavorite ? "heart.fill" : "hands.sparkles.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color(hexToken: isFavorite ? tokens.accent : tokens.primary))
            }
            .frame(width: 40, height: 40)
            .accessibilityHidden(true)

            VStack(alignment: .trailing, spacing: 3) {
                Text(dua.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color(hexToken: tokens.onSurface))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                if !dua.source.isEmpty {
                    Text(dua.source)
                        .font(.caption)
                        .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary).opacity(0.6))
                .accessibilityHidden(true)
        }
        .brandCard(tokens)
        .accessibilityElement(children: .combine)
    }
}
