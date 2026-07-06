import ContentKit
import DesignSystemKit
import SwiftUI

/// Reading view (docs/features/hadith-collections.md screen 2): number badge,
/// Arabic text, grading chip, benefit-note card, prev/next navigation.
public struct HadithReadingScreen: View {
    @State private var viewModel: HadithViewModel
    @Environment(\.colorScheme) private var colorScheme
    private let slug: String
    private let locale: String

    public init(viewModel: HadithViewModel, slug: String, locale: String = "ar") {
        _viewModel = State(initialValue: viewModel)
        self.slug = slug
        self.locale = locale
    }

    private var tokens: ColorTokens {
        colorScheme == .dark ? DesignTokens.bundledDefault.dark : DesignTokens.bundledDefault.light
    }

    public var body: some View {
        Group {
            if let entry = viewModel.currentEntry {
                content(entry)
            } else {
                ProgressView()
            }
        }
        .task { await viewModel.openCollection(slug: slug, locale: locale) }
        .toolbar {
            ToolbarItem(placement: .principal) {
                if let detail = viewModel.currentDetail {
                    Menu {
                        ForEach(detail.entries, id: \.id) { entry in
                            Button("hadith.entry_number \(entry.number)") { viewModel.jumpTo(number: entry.number) }
                        }
                    } label: {
                        Text("hadith.entry_number \(viewModel.currentEntry?.number ?? 0)")
                    }
                }
            }
        }
    }

    private func content(_ entry: HadithEntry) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .trailing, spacing: 16) {
                    HStack {
                        Text("hadith.entry_number \(entry.number)")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color(hexToken: tokens.primaryContainer), in: Capsule())
                        Spacer()
                        Text(entry.grading)
                            .font(.caption)
                            .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                    }

                    Text(entry.arabicText)
                        .font(.title3)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    if let translation = entry.translation {
                        Text(translation)
                            .font(.body)
                            .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let benefitNote = entry.benefitNote {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("hadith.benefit_label")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color(hexToken: tokens.primary))
                            Text(benefitNote).font(.subheadline)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding()
                        .background(Color(hexToken: tokens.primaryContainer), in: RoundedRectangle(cornerRadius: 14))
                    }

                    if !entry.source.isEmpty {
                        Text(entry.source)
                            .font(.caption)
                            .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .padding()
            }

            HStack(spacing: 12) {
                Button("hadith.previous") { viewModel.previous() }
                    .buttonStyle(.bordered)
                    .disabled(isAtFirst)
                Button("hadith.next") { viewModel.next() }
                    .buttonStyle(.borderedProminent)
                    .disabled(isAtLast)
            }
            .padding()
        }
    }

    private var isAtFirst: Bool { viewModel.currentIndex == 0 }
    private var isAtLast: Bool {
        guard let detail = viewModel.currentDetail else { return true }
        return viewModel.currentIndex >= detail.entries.count - 1
    }
}
