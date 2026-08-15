import AzkarFeature
import ContentKit
import DesignSystemKit
import DuaFeature
import SwiftUI

/// Azkar and Du'a merged into one screen behind a single category strip
/// (client direction, 2026-08-15) — replacing the earlier Azkar/Du'a
/// segmented control (2026-07-26) with one continuous row of chips spanning
/// both corpora, so the screen reads as one table of contents rather than
/// two tabs the reader has to know to switch between.
///
/// The two libraries still keep their own view models and their own session/
/// favourites logic; only the chip strip, search field, and card list are
/// unified here. A chip's *kind* (azkar category, dua category, or dua
/// favourites) decides which card style and per-item actions render below it.
struct RemembranceScreen: View {
    /// Which corpus opens by default — set by which deep link/tile got here
    /// (`fatwabot://azkar` vs `fatwabot://dua`). Both still land on this one
    /// screen; this only picks the initially-selected chip.
    enum Segment: String {
        case azkar, dua
    }

    private enum Selection: Equatable {
        case azkar(String)   // AzkarCategory.id
        case dua(String)     // DuaCategory.id
        case favorites
    }

    private let initial: Segment
    private let azkarViewModel: AzkarViewModel
    private let duaViewModel: DuaViewModel
    /// Which specific item to scroll to, from a content-reminder tap. Only
    /// azkar reminders exist today (`PlannedContentReminder.Kind` has no
    /// `.dua` case), so this only ever selects an azkar chip.
    private let focus: ContentFocus?

    @State private var selection: Selection?
    @State private var query = ""
    @State private var highlightedItemID: String?

    @Environment(\.colorScheme) private var colorScheme
    private var tokens: ColorTokens {
        colorScheme == .dark ? DesignTokens.bundledDefault.dark : DesignTokens.bundledDefault.light
    }

    init(
        initial: Segment, azkarViewModel: AzkarViewModel, duaViewModel: DuaViewModel,
        focus: ContentFocus? = nil
    ) {
        self.initial = initial
        self.azkarViewModel = azkarViewModel
        self.duaViewModel = duaViewModel
        self.focus = focus
    }

    private var azkarCategories: [AzkarCategory] { azkarViewModel.categories }
    private var duaCategories: [DuaCategory] { duaViewModel.categories }
    private var showsFavoritesChip: Bool { !duaViewModel.favoriteDuas.isEmpty }
    private var isLoading: Bool { azkarViewModel.isLoadingCategories || duaViewModel.isLoadingCategories }

    /// Resolves the stored selection to something guaranteed valid, falling
    /// back the same way each original screen did when the stored id goes
    /// stale: a content resync dropping a category, or unfavouriting the
    /// last dua while favourites is what's selected.
    private var resolvedSelection: Selection? {
        switch selection {
        case .azkar(let id) where azkarCategories.contains(where: { $0.id == id }):
            return selection
        case .dua(let id) where duaCategories.contains(where: { $0.id == id }):
            return selection
        case .favorites where showsFavoritesChip:
            return selection
        default:
            break
        }
        if let first = azkarCategories.first { return .azkar(first.id) }
        if let first = duaCategories.first { return .dua(first.id) }
        return nil
    }

    private var selectedAzkarCategory: AzkarCategory? {
        guard case .azkar(let id) = resolvedSelection else { return nil }
        return azkarCategories.first { $0.id == id }
    }

    private var selectedDuaCategory: DuaCategory? {
        guard case .dua(let id) = resolvedSelection else { return nil }
        return duaCategories.first { $0.id == id }
    }

    /// Search covers title, matn and source for azkar (before titles existed
    /// it was the only way most entries could be found by) and is scoped to
    /// the active category, unlike dua search below.
    private var visibleAzkarItems: [AzkarItem] {
        AzkarSearch.filter(selectedAzkarCategory?.items ?? [], query: query)
    }

    /// Dua search already spans every category once a query is entered
    /// (`DuaViewModel.searchResults`) — kept as-is rather than narrowed to
    /// the active chip.
    private var visibleDuas: [Dua] {
        if let results = duaViewModel.searchResults { return results }
        if resolvedSelection == .favorites { return duaViewModel.favoriteDuas }
        return selectedDuaCategory?.duas ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            searchField
            categoryChips
            content
        }
        .brandScreenBackground(tokens)
        .task {
            async let azkarLoad: Void = azkarViewModel.loadCategories(locale: "ar")
            async let duaLoad: Void = duaViewModel.loadCategories(locale: "ar")
            _ = await (azkarLoad, duaLoad)
            // Land on the category a reminder's item actually belongs to —
            // without this the item may not even be in `visibleAzkarItems`
            // yet, since that is filtered to whichever chip is selected.
            if let focusCategoryID = focus?.categorySlug {
                selection = .azkar(focusCategoryID)
            } else if selection == nil {
                selection = initial == .dua
                    ? duaCategories.first.map { .dua($0.id) }
                    : azkarCategories.first.map { .azkar($0.id) }
            }
        }
    }

    // MARK: - Header

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
            TextField("azkar.search_placeholder", text: $query)
                .textFieldStyle(.plain)
                .foregroundStyle(Color(hexToken: tokens.onSurface))
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !query.isEmpty {
                Button {
                    query = ""
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
        .onChange(of: query) { _, newValue in
            // Dua's own search is what actually spans every dua category;
            // azkar filters locally via `visibleAzkarItems`.
            duaViewModel.searchQuery = newValue
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(azkarCategories) { category in
                    chip(title: category.name, systemImage: nil, isSelected: resolvedSelection == .azkar(category.id)) {
                        select(.azkar(category.id))
                    }
                }
                if showsFavoritesChip {
                    chip(
                        title: String(localized: "dua.favorites"), systemImage: "heart.fill",
                        isSelected: resolvedSelection == .favorites
                    ) {
                        select(.favorites)
                    }
                }
                ForEach(duaCategories) { category in
                    chip(title: category.name, systemImage: nil, isSelected: resolvedSelection == .dua(category.id)) {
                        select(.dua(category.id))
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 14)
    }

    private func select(_ newSelection: Selection) {
        selection = newSelection
        // A query from the previous chip almost never applies to the next
        // one, and leaving it set shows an empty list that reads as though
        // the category itself is empty.
        query = ""
        duaViewModel.searchQuery = ""
    }

    private func chip(title: String, systemImage: String?, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
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
                    isSelected ? Color(hexToken: tokens.primary) : Color(hexToken: tokens.surfaceElevated)
                )
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: - Body

    @ViewBuilder
    private var content: some View {
        if azkarCategories.isEmpty && duaCategories.isEmpty {
            if isLoading {
                ProgressView()
                    .tint(Color(hexToken: tokens.primary))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                BrandEmptyState(
                    systemImage: "book.closed", messageKey: "azkar.empty_state", tokens: tokens
                )
                .frame(maxHeight: .infinity)
            }
        } else {
            switch resolvedSelection {
            case .azkar:
                azkarContent
            case .dua, .favorites:
                duaContent
            case nil:
                ProgressView()
                    .tint(Color(hexToken: tokens.primary))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Azkar content

    @ViewBuilder
    private var azkarContent: some View {
        if visibleAzkarItems.isEmpty {
            BrandEmptyState(
                systemImage: "magnifyingglass", messageKey: "azkar.search_empty", tokens: tokens
            )
            .frame(maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if let category = selectedAzkarCategory {
                            startSessionRow(category)
                        }
                        ForEach(visibleAzkarItems) { item in
                            azkarCard(item).id(item.id)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
                // Runs once the focused item actually appears in the list —
                // it isn't there on the first pass while `.task` above is
                // still loading and switching to the right category.
                .onChange(of: visibleAzkarItems.map(\.id)) { _, ids in
                    guard let focusItemID = focus?.contentID, ids.contains(focusItemID) else { return }
                    scrollToFocus(focusItemID, proxy: proxy)
                }
                .onAppear {
                    guard let focusItemID = focus?.contentID,
                          visibleAzkarItems.contains(where: { $0.id == focusItemID }) else { return }
                    scrollToFocus(focusItemID, proxy: proxy)
                }
            }
        }
    }

    /// Scrolls to and briefly highlights the item a content-reminder tap
    /// named — a plain jump-to would land the reader on the right passage
    /// with no sense of why THAT card, among a whole category of nearly
    /// identical cards, is the one the notification meant.
    private func scrollToFocus(_ id: String, proxy: ScrollViewProxy) {
        withAnimation { proxy.scrollTo(id, anchor: .center) }
        withAnimation { highlightedItemID = id }
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            withAnimation { highlightedItemID = nil }
        }
    }

    /// The way into the counting session, kept at the top of the list rather
    /// than on every card: starting a session is a per-category action, and
    /// repeating it on every card would imply each one starts its own.
    private func startSessionRow(_ category: AzkarCategory) -> some View {
        NavigationLink {
            AzkarSessionScreen(viewModel: azkarViewModel, category: category)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: azkarViewModel.isCompletedToday(category.id)
                      ? "checkmark.seal.fill" : "play.circle.fill")
                    .font(.title3)
                Text("azkar.start_session")
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 0)
                Text("\(category.items.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
            }
            .foregroundStyle(Color(hexToken: tokens.primary))
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(hexToken: tokens.primary).opacity(0.09))
            )
        }
        .buttonStyle(.plain)
    }

    private func azkarCard(_ item: AzkarItem) -> some View {
        ArabicContentCard(
            label: item.title,
            badgeText: RepeatCountLabel.text(item.repeatCount, locale: Locale(identifier: "ar")),
            arabic: item.arabicText,
            tokens: tokens
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color(hexToken: tokens.primary), lineWidth: highlightedItemID == item.id ? 2.5 : 0)
        )
    }

    // MARK: - Du'a content

    @ViewBuilder
    private var duaContent: some View {
        if visibleDuas.isEmpty {
            // Distinguishing these matters: "no matches" and "this category is
            // empty" look identical otherwise, and the first is the user's
            // doing while the second is ours.
            BrandEmptyState(
                systemImage: "magnifyingglass",
                messageKey: duaViewModel.searchResults == nil ? "dua.empty_state" : "dua.search_no_results",
                tokens: tokens
            )
            .frame(maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(visibleDuas) { dua in
                        duaCard(dua)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
    }

    private func duaCard(_ dua: Dua) -> some View {
        ArabicContentCard(
            label: dua.displayTitle,
            arabic: dua.arabicText,
            tokens: tokens
        ) {
            favoriteButton(dua)
        }
    }

    private func favoriteButton(_ dua: Dua) -> some View {
        let isFavorite = duaViewModel.isFavorite(dua.id)
        return Button {
            duaViewModel.toggleFavorite(dua.id)
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
