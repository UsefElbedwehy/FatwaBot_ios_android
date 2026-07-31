import ContentKit
import DesignSystemKit
import CoreKit
import SwiftUI

/// Reading view (docs/features/dua.md screen 3): Arabic text, toggleable
/// transliteration/translation, source, favorite toggle, share.
public struct DuaReadingScreen: View {
    @State private var viewModel: DuaViewModel
    @State private var showTransliteration = true
    @Environment(\.colorScheme) private var colorScheme
    private let dua: Dua

    public init(viewModel: DuaViewModel, dua: Dua) {
        _viewModel = State(initialValue: viewModel)
        self.dua = dua
    }

    private var tokens: ColorTokens {
        colorScheme == .dark ? DesignTokens.bundledDefault.dark : DesignTokens.bundledDefault.light
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .trailing, spacing: 18) {
                header

                arabicCard

                if showTransliteration, let transliteration = dua.transliteration {
                    transliterationCard(transliteration)
                }

                if let translation = dua.translation {
                    translationCard(translation)
                }

                if !dua.source.isEmpty {
                    sourceRow
                }
            }
            .padding(20)
        }
        .brandScreenBackground(tokens)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.toggleFavorite(dua.id)
                } label: {
                    Image(systemName: viewModel.isFavorite(dua.id) ? "heart.fill" : "heart")
                }
                .tint(Color(hexToken: tokens.primary))
                .accessibilityLabel(Text(viewModel.isFavorite(dua.id) ? "dua.unfavorite" : "dua.favorite"))
            }
            ToolbarItem(placement: .primaryAction) {
                ShareLink(item: shareText)
            }
            if dua.transliteration != nil {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showTransliteration.toggle()
                    } label: {
                        Image(systemName: showTransliteration ? "textformat.abc" : "textformat")
                    }
                    .accessibilityLabel(Text("dua.toggle_transliteration"))
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            ArchIconBadge(systemImage: "hands.sparkles", tokens: tokens, size: CGSize(width: 66, height: 76))
            Text(dua.displayTitle)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color(hexToken: tokens.onSurface))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Arabic centerpiece

    private var arabicCard: some View {
        Text(dua.arabicText.expandingArabicHonorifics)
            .font(.system(size: 30, weight: .semibold, design: .serif))
            .lineSpacing(14)
            .multilineTextAlignment(.trailing)
            .foregroundStyle(Color(hexToken: tokens.onSurface))
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(24)
            .background(
                LinearGradient(
                    colors: [
                        Color(hexToken: tokens.primaryContainer),
                        Color(hexToken: tokens.surfaceElevated),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 24, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color(hexToken: tokens.primary).opacity(0.15), lineWidth: 1)
            )
            .shadow(color: Color(hexToken: tokens.primary).opacity(0.10), radius: 16, x: 0, y: 8)
    }

    // MARK: - Transliteration / translation

    private func transliterationCard(_ transliteration: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("dua.toggle_transliteration", systemImage: "textformat.abc")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(hexToken: tokens.accent))
                .accessibilityHidden(true)
            Text(transliteration)
                .font(.body.italic())
                .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hexToken: tokens.primaryContainer).opacity(0.4), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(hexToken: tokens.outline).opacity(0.5), lineWidth: 1)
        )
    }

    private func translationCard(_ translation: String) -> some View {
        Text(translation)
            .font(.body)
            .foregroundStyle(Color(hexToken: tokens.onSurface))
            .frame(maxWidth: .infinity, alignment: .leading)
            .brandCard(tokens)
    }

    // MARK: - Source

    private var sourceRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "book.closed.fill")
                .font(.caption)
                .foregroundStyle(Color(hexToken: tokens.accent))
                .accessibilityHidden(true)
            Text(dua.source)
                .font(.caption)
                .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var shareText: String {
        [dua.title, dua.arabicText, dua.translation, dua.source]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }
}
