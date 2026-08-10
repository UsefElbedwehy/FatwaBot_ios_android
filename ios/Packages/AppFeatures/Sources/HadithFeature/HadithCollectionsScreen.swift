import ContentKit
import CoreKit
import DesignSystemKit
import SwiftUI

/// Browsing the hadith corpus: a chip per collection, and every entry in the
/// selected one as a card.
///
/// ## Why this replaced the reader
/// Hadith used to be two screens. This one listed the five collections as rows
/// with progress rings; tapping one opened `HadithReadingScreen`, which showed a
/// single entry at a time behind «السابق» / «التالي» buttons, with a dropdown to
/// jump to a numbered entry.
///
/// That shape makes a collection unreadable as a collection. You cannot see what
/// is in it, cannot scan for the hadith you half-remember, and cannot get from
/// entry 3 to entry 40 without either forty taps or knowing the number you want.
/// Azkar had already solved the same problem for the same kind of content one
/// tab away — chips across the top, everything below in one scroll — and the
/// owner asked for hadith to match it.
///
/// ## What went with it
/// The prev/next reader is gone, and with it the per-entry translation block and
/// the «الفائدة» benefit-note card. The API still returns both.
///
/// Progress did *not* go with it, because it feeds the streak. It changed
/// meaning instead: see ``HadithViewModel/markRead(number:)`` for why "read" now
/// means "scrolled into view" and what that costs.
public struct HadithCollectionsScreen: View {
    @State private var viewModel: HadithViewModel
    @State private var selectedSlug: String?
    @Environment(\.colorScheme) private var colorScheme
    private let locale: String

    public init(viewModel: HadithViewModel, locale: String = "ar") {
        _viewModel = State(initialValue: viewModel)
        self.locale = locale
    }

    private var tokens: ColorTokens {
        colorScheme == .dark ? DesignTokens.bundledDefault.dark : DesignTokens.bundledDefault.light
    }

    /// Collections that actually have approved entries.
    ///
    /// The backend serves only reviewed hadith, so a collection still under
    /// review comes down with `entryCount == 0`. The old screen showed those as
    /// dimmed, non-tappable rows. As a chip there is nothing equivalent — a chip
    /// that cannot be selected reads as a broken control — so they are left out
    /// of the strip and surfaced in the empty state instead.
    private var readableCollections: [HadithCollectionSummary] {
        viewModel.collections.filter { $0.entryCount > 0 }
    }

    /// Resolved rather than read straight from state: a content resync can drop
    /// the selected collection, which would otherwise leave every chip
    /// unhighlighted over an empty list.
    private var activeSlug: String? {
        if let selectedSlug, readableCollections.contains(where: { $0.slug == selectedSlug }) {
            return selectedSlug
        }
        return readableCollections.first?.slug
    }

    /// Entries of the loaded collection, but only once it is the one selected.
    ///
    /// `currentDetail` lags `activeSlug` by one async load. Without this guard
    /// the previous collection's entries render under the newly selected chip
    /// for a frame or two, which looks like the wrong content rather than a
    /// pending one.
    private var entries: [HadithEntry] {
        guard let detail = viewModel.currentDetail, detail.slug == activeSlug else { return [] }
        return detail.entries
    }

    public var body: some View {
        VStack(spacing: 0) {
            collectionChips
            content
        }
        .brandScreenBackground(tokens)
        .task { await viewModel.loadCollections(locale: locale) }
        // Keyed on the resolved slug, not the raw selection, so the first load
        // (where nothing is selected yet and `activeSlug` falls back to the
        // first collection) fetches too.
        .task(id: activeSlug) {
            guard let activeSlug else { return }
            await viewModel.openCollection(slug: activeSlug, locale: locale)
        }
    }

    // MARK: - Chips

    private var collectionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(readableCollections) { collection in
                    chip(collection)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 4)
        .padding(.bottom, 14)
    }

    private func chip(_ collection: HadithCollectionSummary) -> some View {
        let isSelected = collection.slug == activeSlug
        let completed = viewModel.isCompleted(
            slug: collection.slug, totalEntries: collection.entryCount
        )
        return Button {
            selectedSlug = collection.slug
        } label: {
            HStack(spacing: 5) {
                // The progress ring from the old rows does not survive at chip
                // size, but "finished" is the part worth keeping.
                if completed {
                    Image(systemName: "checkmark.seal.fill").font(.caption)
                }
                Text(collection.name)
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
        if readableCollections.isEmpty {
            if viewModel.isLoadingCollections {
                ProgressView()
                    .tint(Color(hexToken: tokens.primary))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Covers both "nothing came down" and "everything that came down
                // is still under review" — from here they are the same thing.
                BrandEmptyState(
                    systemImage: "text.book.closed",
                    messageKey: viewModel.collections.isEmpty
                        ? "hadith.empty_state" : "hadith.under_review",
                    tokens: tokens
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else if entries.isEmpty {
            ProgressView()
                .tint(Color(hexToken: tokens.primary))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(entries, id: \.id) { entry in
                        card(entry)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
    }

    private func card(_ entry: HadithEntry) -> some View {
        ArabicContentCard(
            label: entry.grading.expandingArabicHonorifics,
            badgeText: "\(entry.number)",
            // The stored matn still ends with its own takhrij — migration 0029
            // copied that clause into `grading` rather than moving it — so
            // without this the attribution shows twice, once as the label and
            // again trailing the text.
            arabic: HadithDisplay.matnWithoutTakhrij(entry.arabicText, grading: entry.grading),
            tokens: tokens
        )
        .onAppear { viewModel.markRead(number: entry.number) }
    }
}
