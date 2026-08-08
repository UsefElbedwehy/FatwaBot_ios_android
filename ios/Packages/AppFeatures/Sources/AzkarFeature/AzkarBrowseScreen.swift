import ContentKit
import CoreKit
import DesignSystemKit
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

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
/// ## Where this departs from the reference design
/// The reference puts each title in a solid filled header band. At three cards
/// per screen that turns a reading surface into a stack of alerts and fights the
/// calm cream the rest of the app uses. Here the title is maroon type over the
/// same card surface with a hairline rule under it — same hierarchy, a third of
/// the visual weight.
///
/// The repeat count is likewise a quiet marker rather than a filled pill: it
/// matters *while* reciting, not while choosing what to recite, so it should not
/// compete with the title for first read.
public struct AzkarBrowseScreen: View {
    @State private var viewModel: AzkarViewModel
    @State private var selectedCategoryId: String?
    @State private var query: String = ""
    @Environment(\.colorScheme) private var colorScheme
    private let locale: String

    public init(viewModel: AzkarViewModel, locale: String = "ar") {
        _viewModel = State(initialValue: viewModel)
        self.locale = locale
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
        .task { await viewModel.loadCategories(locale: locale) }
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
            ScrollView {
                LazyVStack(spacing: 12) {
                    if let category = selectedCategory {
                        startSessionRow(category)
                    }
                    ForEach(visibleItems) { item in
                        card(item)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
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

    private func card(_ item: AzkarItem) -> some View {
        BrandCard(tokens, padding: 18) {
            VStack(alignment: .trailing, spacing: 12) {
                header(item)

                Text(item.arabicText.expandingArabicHonorifics)
                    .font(.title3.weight(.medium))
                    .lineSpacing(8)
                    .foregroundStyle(Color(hexToken: tokens.onSurface))
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                if let translation = item.translation, !translation.isEmpty {
                    Text(translation)
                        .font(.footnote)
                        .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                copyButton(item)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(item.title ?? item.source))
    }

    /// Title, source and repeat count.
    ///
    /// The whole header is skipped when there is nothing to put in it — an
    /// untitled entry with no source would otherwise get an empty band and a
    /// rule floating above its matn.
    @ViewBuilder
    private func header(_ item: AzkarItem) -> some View {
        let title = item.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasTitle = !(title ?? "").isEmpty
        if hasTitle || !item.source.isEmpty || item.repeatCount > 1 {
            VStack(alignment: .trailing, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if item.repeatCount > 1 {
                        Text(verbatim: "×\(item.repeatCount)")
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(Color(hexToken: tokens.primary))
                            .accessibilityLabel(Text("azkar.repeat_a11y \(item.repeatCount)"))
                    }
                    Spacer(minLength: 0)
                    if hasTitle, let title {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(Color(hexToken: tokens.primary))
                            .multilineTextAlignment(.trailing)
                    } else if !item.source.isEmpty {
                        // No title yet: the source carries the header alone
                        // rather than leaving it blank, which is what most of
                        // the corpus looks like until titles land.
                        Text(item.source)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color(hexToken: tokens.primary))
                    }
                }
                if hasTitle, !item.source.isEmpty {
                    Text(item.source)
                        .font(.caption)
                        .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                }
                Divider().overlay(Color(hexToken: tokens.outline))
            }
        }
    }

    private func copyButton(_ item: AzkarItem) -> some View {
        HStack {
            Button {
                #if canImport(UIKit)
                // The matn as displayed, not as stored: the reader sees expanded
                // honorifics, and pasting ligatures they never saw into a message
                // that renders them as ▯ boxes would be a surprise.
                UIPasteboard.general.string = item.arabicText.expandingArabicHonorifics
                #endif
            } label: {
                Label("azkar.copy", systemImage: "doc.on.doc")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color(hexToken: tokens.primary))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        Capsule().fill(Color(hexToken: tokens.primary).opacity(0.10))
                    )
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)
        }
    }
}
