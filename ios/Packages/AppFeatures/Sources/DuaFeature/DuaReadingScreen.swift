import ContentKit
import DesignSystemKit
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
            VStack(alignment: .trailing, spacing: 16) {
                Text(dua.title)
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .trailing)

                Text(dua.arabicText)
                    .font(.title2)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                if showTransliteration, let transliteration = dua.transliteration {
                    Text(transliteration)
                        .font(.body.italic())
                        .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let translation = dua.translation {
                    Text(translation)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !dua.source.isEmpty {
                    Text(dua.source)
                        .font(.caption)
                        .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.toggleFavorite(dua.id)
                } label: {
                    Image(systemName: viewModel.isFavorite(dua.id) ? "heart.fill" : "heart")
                }
                .tint(Color(hexToken: tokens.primary))
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
                }
            }
        }
    }

    private var shareText: String {
        [dua.title, dua.arabicText, dua.translation, dua.source]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }
}
