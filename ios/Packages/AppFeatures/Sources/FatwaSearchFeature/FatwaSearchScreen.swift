import DesignSystemKit
import SwiftUI

/// Answer screen for all three AI-search entry points (docs/features/
/// ai-search-m5.0-spec.md §App wiring) — one screen, mode decides the title,
/// placeholder and idle hint. Citations show the quote + page + book title
/// (v1: no deep-linking to an in-app reader, per spec).
public struct FatwaSearchScreen: View {
    @State private var viewModel: FatwaSearchViewModel
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isFocused: Bool

    public init(viewModel: FatwaSearchViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    private var tokens: ColorTokens {
        colorScheme == .dark ? DesignTokens.bundledDefault.dark : DesignTokens.bundledDefault.light
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .trailing, spacing: 20) {
                questionField
                content
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

    // MARK: - Question field

    private var questionField: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: viewModel.mode.systemImage)
                    .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                TextField(viewModel.mode.placeholderKey, text: $viewModel.question, axis: .vertical)
                    .textFieldStyle(.plain)
                    .foregroundStyle(Color(hexToken: tokens.onSurface))
                    .lineLimit(1...4)
                    .focused($isFocused)
                    .submitLabel(.search)
                    .onSubmit { Task { await viewModel.submit() } }
                    .disabled(isLoading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color(hexToken: tokens.surfaceElevated)))

            Button {
                isFocused = false
                Task { await viewModel.submit() }
            } label: {
                Text("fatwa_search.submit")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(hexToken: tokens.primary), in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(Color(hexToken: tokens.onPrimary))
            }
            .buttonStyle(.plain)
            .disabled(isLoading || viewModel.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(isLoading || viewModel.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
        }
    }

    private var isLoading: Bool { viewModel.phase == .loading }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .idle:
            BrandEmptyState(systemImage: viewModel.mode.systemImage, messageKey: viewModel.mode.hintKey, tokens: tokens)
        case .loading:
            DhikrLoadingView(tokens: tokens)
        case .unavailable:
            unavailableCard
        case .error(let message):
            errorCard(message)
        case .result(let response):
            resultView(response)
        }
    }

    private var unavailableCard: some View {
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

    private func errorCard(_ message: String) -> some View {
        VStack(spacing: 14) {
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
            Button {
                Task { await viewModel.submit() }
            } label: {
                Text("fatwa_search.retry")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(hexToken: tokens.primary))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private func resultView(_ response: SearchResponse) -> some View {
        VStack(alignment: .trailing, spacing: 16) {
            BrandSectionHeader(
                response.refused ? "fatwa_search.no_answer" : "fatwa_search.answer",
                systemImage: response.refused ? "questionmark.circle" : "text.bubble.fill",
                tokens: tokens
            )
            BrandCard(tokens) {
                Text(response.answer)
                    .font(.body)
                    .foregroundStyle(Color(hexToken: tokens.onSurface))
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            if !response.citations.isEmpty {
                BrandSectionHeader("fatwa_search.sources", systemImage: "books.vertical.fill", tokens: tokens)
                ForEach(response.citations) { citation in
                    ArabicContentCard(
                        label: "\(citation.sourceTitle) — \(citation.scholar)",
                        badgeText: citation.pageNumber.map { String(format: NSLocalizedString("fatwa_search.page_badge", comment: ""), $0) },
                        arabic: citation.quotedText,
                        tokens: tokens
                    )
                }
            }

            askAgainButton
        }
    }

    private var askAgainButton: some View {
        Button {
            viewModel.reset()
        } label: {
            Text("fatwa_search.ask_again")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(hexToken: tokens.primaryContainer), in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(Color(hexToken: tokens.primary))
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }
}
