import ContentKit
import DesignSystemKit
import SwiftUI

/// Browsing the du'a corpus: category chips, search, and every dua in the
/// selected category as a card carrying the dua itself.
///
/// ## Why this replaced the previous library
/// The old screen was a directory, not a reader. Categories were stacked
/// sections of row cards showing a *title* and a source line; reading the actual
/// dua meant tapping through to a detail page, which then presented it as four
/// stacked blocks — an Arabic centrepiece, a transliteration card, a translation
/// card and a source row.
///
/// So the same dua looked like one thing here and a different thing there, and
/// neither matched how Azkar presented an identical kind of passage two tabs
/// away. The owner's direction was to show the passage and drop the apparatus,
/// and to make Du'a behave like Azkar. Both are the same fix: one list, one
/// card, the text right there.
///
/// ## What went with it
/// `DuaReadingScreen` is gone, and with it the transliteration and translation
/// blocks and the takhrij source line. The data still comes down from the API —
/// nothing was deleted server-side — it is simply not on this surface.
///
/// The favourite toggle did *not* go with it. It lived in that page's toolbar
/// and is a persisted, user-facing feature, so it moved onto the card rather
/// than disappearing as a side effect.
public struct DuaLibraryScreen: View {
    @State private var viewModel: DuaViewModel
    /// `nil` selects the first category; ``favoritesChipId`` selects favourites.
    @State private var selectedCategoryId: String?
    @Environment(\.colorScheme) private var colorScheme
    private let locale: String

    /// Sentinel id for the favourites chip. Not a real category, and cannot
    /// collide with one: server category ids are UUIDs.
    private static let favoritesChipId = "__favorites__"

    public init(viewModel: DuaViewModel, locale: String = "ar") {
        _viewModel = State(initialValue: viewModel)
        self.locale = locale
    }

    private var tokens: ColorTokens {
        colorScheme == .dark ? DesignTokens.bundledDefault.dark : DesignTokens.bundledDefault.light
    }

    private var showsFavoritesChip: Bool { !viewModel.favoriteDuas.isEmpty }

    /// The chip actually in effect.
    ///
    /// Resolved rather than read straight from state because the stored id can
    /// go stale: unfavouriting the last dua removes the favourites chip while it
    /// is selected, and a content resync can drop a category entirely. Both
    /// would otherwise leave the list empty with every chip unhighlighted.
    private var activeChipId: String? {
        if selectedCategoryId == Self.favoritesChipId {
            return showsFavoritesChip ? Self.favoritesChipId : viewModel.categories.first?.id
        }
        if let selectedCategoryId,
           viewModel.categories.contains(where: { $0.id == selectedCategoryId }) {
            return selectedCategoryId
        }
        return viewModel.categories.first?.id
    }

    /// Search wins over the chip selection: a query is a deliberate act and
    /// filtering it down to one category would hide matches the user can see are
    /// there.
    private var visibleDuas: [Dua] {
        if let results = viewModel.searchResults { return results }
        if activeChipId == Self.favoritesChipId { return viewModel.favoriteDuas }
        return viewModel.categories.first { $0.id == activeChipId }?.duas ?? []
    }

    public var body: some View {
        VStack(spacing: 0) {
            searchField
            categoryChips
            content
        }
        .brandScreenBackground(tokens)
        .task { await viewModel.loadCategories(locale: locale) }
    }

    // MARK: - Header

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
            TextField("dua.search_placeholder", text: $viewModel.searchQuery)
                .textFieldStyle(.plain)
                .foregroundStyle(Color(hexToken: tokens.onSurface))
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("azkar.search_clear"))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(hexToken: tokens.surfaceElevated))
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if showsFavoritesChip {
                    chip(
                        title: String(localized: "dua.favorites"),
                        id: Self.favoritesChipId,
                        systemImage: "heart.fill"
                    )
                }
                ForEach(viewModel.categories) { category in
                    chip(title: category.name, id: category.id, systemImage: nil)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 14)
    }

    private func chip(title: String, id: String, systemImage: String?) -> some View {
        let isSelected = id == activeChipId
        return Button {
            selectedCategoryId = id
            // A query from the previous chip almost never applies to the next
            // one, and leaving it set shows an empty list that reads as though
            // the category itself is empty.
            viewModel.searchQuery = ""
        } label: {
            HStack(spacing: 5) {
                if let systemImage {
                    Image(systemName: systemImage).font(.caption)
                }
                Text(verbatim: title)
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
            }
            .foregroundStyle(Color(hexToken: isSelected ? tokens.onPrimary : tokens.onSurface))
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(
                Capsule().fill(
                    isSelected
                        ? Color(hexToken: tokens.primary)
                        : Color(hexToken: tokens.surfaceElevated)
                )
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: - Body

    @ViewBuilder
    private var content: some View {
        if viewModel.categories.isEmpty {
            if viewModel.isLoadingCategories {
                ProgressView()
                    .tint(Color(hexToken: tokens.primary))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                BrandEmptyState(
                    systemImage: "hands.sparkles", messageKey: "dua.empty_state", tokens: tokens
                )
                .frame(maxHeight: .infinity)
            }
        } else if visibleDuas.isEmpty {
            // Distinguishing these matters: "no matches" and "this category is
            // empty" look identical otherwise, and the first is the user's doing
            // while the second is ours.
            BrandEmptyState(
                systemImage: "magnifyingglass",
                messageKey: viewModel.searchResults == nil
                    ? "dua.empty_state" : "dua.search_no_results",
                tokens: tokens
            )
            .frame(maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(visibleDuas) { dua in
                        card(dua)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
    }

    private func card(_ dua: Dua) -> some View {
        ArabicContentCard(
            label: dua.displayTitle,
            arabic: dua.arabicText,
            tokens: tokens
        ) {
            favoriteButton(dua)
        }
    }

    private func favoriteButton(_ dua: Dua) -> some View {
        let isFavorite = viewModel.isFavorite(dua.id)
        return Button {
            viewModel.toggleFavorite(dua.id)
        } label: {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.caption.weight(.medium))
                .foregroundStyle(Color(hexToken: isFavorite ? tokens.accent : tokens.primary))
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(
                    Capsule().fill(
                        Color(hexToken: isFavorite ? tokens.accent : tokens.primary).opacity(0.10)
                    )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(isFavorite ? "dua.unfavorite" : "dua.favorite"))
    }
}
