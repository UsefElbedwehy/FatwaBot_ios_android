import ContentKit
import CoreKit
import DesignSystemKit
import SwiftUI

/// Browsing the azkar corpus: category chips, search, and every entry in the
/// selected category as a scannable card.
///
/// ## Why this exists next to the counting session
/// `AzkarSessionScreen` shows one dhikr at a time behind a counter, which is the
/// right shape for *performing* adhkar and is what feeds the streak. It is the
/// wrong shape for finding one — you cannot see what a category contains without
/// counting through it, and you cannot copy a specific dua without starting a
/// session you did not want.
///
/// So this screen answers "what is in here / where is the one I want", and the
/// session answers "help me say it". Tapping a card's counter affordance still
/// opens the session, so nothing is lost.
///
/// ## Presentation
/// Every entry is an ``ArabicContentCard`` — the same component Du'a and Hadith
/// use, so the same passage looks identical wherever it is reached from. The
/// card carries the passage and nothing else; see its documentation for what was
/// deliberately taken off this surface and why.
public struct AzkarBrowseScreen: View {
    @State private var viewModel: AzkarViewModel
    @State private var selectedCategoryId: String?
    @State private var query: String = ""
    @State private var highlightedItemID: String?
    @Environment(\.colorScheme) private var colorScheme
    private let locale: String
    /// A specific item to land on — from a content-reminder tap
    /// (`ContentReminderScheduler`). `nil` for the ordinary "just opened the
    /// tab" path, which is nearly always.
    private let focusItemID: String?
    private let focusCategoryID: String?

    public init(
        viewModel: AzkarViewModel, locale: String = "ar",
        focusItemID: String? = nil, focusCategoryID: String? = nil
    ) {
        _viewModel = State(initialValue: viewModel)
        self.locale = locale
        self.focusItemID = focusItemID
        self.focusCategoryID = focusCategoryID
    }

    private var tokens: ColorTokens {
        colorScheme == .dark ? DesignTokens.bundledDefault.dark : DesignTokens.bundledDefault.light
    }

    private var selectedCategory: AzkarCategory? {
        viewModel.categories.first { $0.id == selectedCategoryId } ?? viewModel.categories.first
    }

    /// Entries matching the query, or all of them when it is empty.
    ///
    /// Search covers title, matn and source. Matn is included deliberately even
    /// though it is the least pleasant to match on — before titles exist it is
    /// the *only* thing most entries can be found by, and a search that silently
    /// returns nothing for an untitled corpus would read as broken.
    private var visibleItems: [AzkarItem] {
        AzkarSearch.filter(selectedCategory?.items ?? [], query: query)
    }

    public var body: some View {
        VStack(spacing: 0) {
            searchField
            categoryChips
            content
        }
        .brandScreenBackground(tokens)
        .task {
            await viewModel.loadCategories(locale: locale)
            // Land on the category the reminder's item actually belongs to —
            // without this the item may not even be in `visibleItems` yet,
            // since that is filtered to whichever category is selected.
            if let focusCategoryID {
                selectedCategoryId = focusCategoryID
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
    }

    private var categoryChips: some View {
        let activeId = selectedCategory?.id
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.categories) { category in
                    let isSelected = category.id == activeId
                    Button {
                        selectedCategoryId = category.id
                        // A query from the previous category almost never applies
                        // to the next one, and leaving it set shows an empty list
                        // that looks like the category itself is empty.
                        query = ""
                    } label: {
                        Text(category.name)
                            .font(.subheadline.weight(isSelected ? .semibold : .regular))
                            .foregroundStyle(
                                Color(hexToken: isSelected ? tokens.onPrimary : tokens.onSurface)
                            )
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
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 14)
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
                    systemImage: "book.closed", messageKey: "azkar.empty_state", tokens: tokens
                )
                .frame(maxHeight: .infinity)
            }
        } else if visibleItems.isEmpty {
            BrandEmptyState(
                systemImage: "magnifyingglass", messageKey: "azkar.search_empty", tokens: tokens
            )
            .frame(maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if let category = selectedCategory {
                            startSessionRow(category)
                        }
                        ForEach(visibleItems) { item in
                            card(item).id(item.id)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
                // Runs once the focused item actually appears in the list —
                // it isn't there on the first pass while `loadCategories` and
                // the category switch from `.task` above are still in flight.
                .onChange(of: visibleItems.map(\.id)) { _, ids in
                    guard let focusItemID, ids.contains(focusItemID) else { return }
                    scrollToFocus(focusItemID, proxy: proxy)
                }
                .onAppear {
                    guard let focusItemID, visibleItems.contains(where: { $0.id == focusItemID }) else { return }
                    scrollToFocus(focusItemID, proxy: proxy)
                }
            }
        }
    }

    /// Scrolls to and briefly highlights the item a content-reminder tap named
    /// — a plain jump-to would land the reader on the right passage with no
    /// sense of why THAT card, among a whole category of nearly identical
    /// cards, is the one the notification meant.
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
    /// repeating it on all 26 cards would imply each one starts its own.
    private func startSessionRow(_ category: AzkarCategory) -> some View {
        NavigationLink {
            AzkarSessionScreen(viewModel: viewModel, category: category)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: viewModel.isCompletedToday(category.id)
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

    /// One entry: title, repeat marker, matn, copy. Nothing else.
    ///
    /// ## What used to be here
    /// The card also rendered `item.source` and `item.translation`. Both are
    /// gone at the owner's direction — "remove the red text and the english
    /// text, keep only the main".
    ///
    /// `source` in particular was never the short attribution its name suggests:
    /// across the corpus it holds a 90–400 character takhrij chain
    /// («عن أنس يرفعه: … أبو داود، برقم ٣٦٦٧، وحسنه الألباني…»), and because it
    /// was the fallback whenever an entry had no title in the active locale, most
    /// cards opened with a paragraph of isnad in brand maroon before the reader
    /// reached the dhikr. The titles now cover the corpus, so the fallback is
    /// gone too — an untitled entry simply shows its matn.
    private func card(_ item: AzkarItem) -> some View {
        ArabicContentCard(
            label: item.title,
            badgeText: RepeatCountLabel.text(
                item.repeatCount, locale: Locale(identifier: locale)
            ),
            arabic: item.arabicText,
            tokens: tokens
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color(hexToken: tokens.primary), lineWidth: highlightedItemID == item.id ? 2.5 : 0)
        )
    }
}
