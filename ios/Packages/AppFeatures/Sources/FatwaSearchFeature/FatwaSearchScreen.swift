import DesignSystemKit
import SwiftUI

/// Answer screen for all three AI-search entry points (docs/features/
/// ai-search-m5.0-spec.md §App wiring) — one screen, mode decides the title,
/// placeholder and idle hint. Citations show the quote + page + book title
/// (v1: no deep-linking to an in-app reader, per spec).
/// The search screen: brand header, mode chips, question field.
///
/// M5.1, from the client's feedback: choosing a mode is selecting a chip and
/// never navigates, and tapping the field opens the keyboard where you already
/// are. Pressing بحث *does* navigate — to `FatwaSearchResultScreen` — because
/// the complaint was being pushed to a second *search* page, not about results
/// having a page of their own. The host watches `phase` to decide which is up.
public struct FatwaSearchScreen<Header: View, BelowField: View>: View {
    @State private var viewModel: FatwaSearchViewModel
    private let header: Header
    private let belowField: BelowField
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isFocused: Bool

    /// Called when the user submits, so the host can push the result page. The
    /// search itself is still driven from here — this only reports that one
    /// started, keeping navigation the host's concern.
    private let onSubmitted: () -> Void

    public init(
        viewModel: FatwaSearchViewModel,
        onSubmitted: @escaping () -> Void = {},
        @ViewBuilder header: () -> Header = { EmptyView() },
        /// Sits directly under the field, in the space the submit button used
        /// to occupy — Home puts its tagline here.
        @ViewBuilder belowField: () -> BelowField = { EmptyView() }
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onSubmitted = onSubmitted
        self.header = header()
        self.belowField = belowField()
    }

    private var tokens: ColorTokens {
        colorScheme == .dark ? DesignTokens.bundledDefault.dark : DesignTokens.bundledDefault.light
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .trailing, spacing: 20) {
                header
                modeChips
                questionField
                belowField
            }
            .padding(20)
        }
        .brandScreenBackground(tokens)
        .navigationTitle(viewModel.mode.titleKey)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        #endif
    }


    /// Push first, then run: the result page owns the loading state, so the
    /// user sees the dhikr view immediately rather than a frozen search screen.
    private func startSearch() {
        guard !viewModel.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        onSubmitted()
        Task { await viewModel.submit() }
    }

    // MARK: - Mode chips

    /// The three modes as chips. Selecting one never navigates — that was the
    /// client's complaint about the old flow — and فتوى is selected by default
    /// because it is what most people come here for.
    private var modeChips: some View {
        HStack(spacing: 8) {
            ForEach(FatwaSearchMode.allCases, id: \.self) { mode in
                let isSelected = mode == viewModel.mode
                Button { viewModel.select(mode: mode) } label: {
                    VStack(spacing: 6) {
                        Image(systemName: mode.systemImage)
                            .font(.system(size: 18, weight: .semibold))
                        Text(mode.titleKey)
                            .font(.caption)
                            .fontWeight(isSelected ? .bold : .regular)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 8)
                    .foregroundStyle(Color(hexToken: isSelected ? tokens.onPrimary : tokens.primary))
                    .background(
                        Color(hexToken: isSelected ? tokens.primary : tokens.surfaceElevated),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
                // Announced as a selectable, not a button, so VoiceOver says
                // whether it is on — the fill is the only other cue.
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }

    // MARK: - Question field

    /// No submit button: the field's own search key runs the search. A second
    /// control for one action was a duplicate, and the space it took is where
    /// the tagline belongs.
    private var questionField: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: viewModel.mode.systemImage)
                    .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                // Single-line on purpose. With `axis: .vertical` SwiftUI treats
                // Return as "insert a newline" and never calls `onSubmit`, so
                // with the submit button gone the keyboard's search key would
                // have been the only way to search and would have done nothing.
                // Long questions scroll within the field instead of wrapping.
                TextField(viewModel.mode.placeholderKey, text: $viewModel.question)
                    .textFieldStyle(.plain)
                    .foregroundStyle(Color(hexToken: tokens.onSurface))
                    .focused($isFocused)
                    .submitLabel(.search)
                    .onSubmit { startSearch() }
                    .disabled(isLoading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color(hexToken: tokens.surfaceElevated)))
        }
    }

    private var isLoading: Bool { viewModel.phase == .loading }



}

/// The result page — everything after بحث: the dhikr loading view, the M5.1
/// result card, or the failure states. Its own page, with its own back.
public struct FatwaSearchResultScreen: View {
    @State private var viewModel: FatwaSearchViewModel
    private let onContact: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    public init(viewModel: FatwaSearchViewModel, onContact: @escaping () -> Void = {}) {
        _viewModel = State(initialValue: viewModel)
        self.onContact = onContact
    }

    private var tokens: ColorTokens {
        colorScheme == .dark ? DesignTokens.bundledDefault.dark : DesignTokens.bundledDefault.light
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .trailing, spacing: 20) {
                switch viewModel.phase {
                // Never rendered: the host swaps back to the search screen the
                // moment the phase returns to idle.
                case .idle:
                    EmptyView()
                case .loading:
                    DhikrLoadingView(tokens: tokens)
                case .unavailable:
                    UnavailableCard(tokens: tokens)
                case .error:
                    // Deliberately not the error's own text — that is how
                    // "Transport(detail=timeout)" reached a user's screen on
                    // Android. It stays on the phase for logging.
                    ErrorCard(tokens: tokens) { Task { await viewModel.submit() } }
                case .result(let response):
                    SearchResultView(
                        response: response,
                        tokens: tokens,
                        onAskAgain: viewModel.reset,
                        onContact: onContact
                    )
                }
            }
            .padding(20)
        }
        .brandScreenBackground(tokens)
        .navigationTitle(viewModel.mode.titleKey)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

/// Shared by the search screen (which never shows them) and the result screen
/// (which does) — extracted when M5.1 split the two, so neither owns a state
/// the other also needs to render.
struct UnavailableCard: View {
    let tokens: ColorTokens

    var body: some View {
        VStack(spacing: 16) {
            BrandLogoBadge(tokens: tokens)
            Text("home.coming_soon.title")
                .font(.title3.weight(.bold))
                .foregroundStyle(Color(hexToken: tokens.onSurface))
            Text("home.coming_soon.body")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 16)
    }
}

struct ErrorCard: View {
    let tokens: ColorTokens
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            // A localized message, never the exception's own text — that is how
            // "Transport(detail=timeout)" reached a user's screen on Android.
            Text("fatwa_search.error_generic")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
            Button(action: onRetry) {
                Text("fatwa_search.retry")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(hexToken: tokens.primary))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}
