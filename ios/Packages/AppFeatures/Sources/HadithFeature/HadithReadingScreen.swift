import ContentKit
import DesignSystemKit
import CoreKit
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
            } else if viewModel.currentDetail != nil {
                // The collection loaded and holds nothing. Previously this fell
                // through to the spinner, so an empty collection was
                // indistinguishable from one still loading — it span forever
                // under a title reading "Hadith #0".
                BrandEmptyState(
                    systemImage: "hourglass",
                    messageKey: "hadith.collection_empty",
                    tokens: tokens
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView().tint(Color(hexToken: tokens.primary))
            }
        }
        .brandScreenBackground(tokens)
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
                VStack(alignment: .trailing, spacing: 18) {
                    HStack {
                        Text("hadith.entry_number \(entry.number)")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Color(hexToken: tokens.primaryContainer), in: Capsule())
                            .foregroundStyle(Color(hexToken: tokens.primary))
                        Spacer()
                        Label(entry.grading.expandingArabicHonorifics, systemImage: "checkmark.seal.fill")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color(hexToken: tokens.accent))
                    }

                    // Reverent centerpiece: the hadith text in an elevated card.
                    Text(
                        HadithDisplay
                            .matnWithoutTakhrij(entry.arabicText, grading: entry.grading)
                            .expandingArabicHonorifics
                    )
                        .font(.system(.title3, design: .serif))
                        .lineSpacing(8)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(20)
                        .background(
                            LinearGradient(
                                colors: [Color(hexToken: tokens.surfaceElevated), Color(hexToken: tokens.primaryContainer).opacity(0.5)],
                                startPoint: .top, endPoint: .bottom
                            ),
                            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(Color(hexToken: tokens.primary).opacity(0.12), lineWidth: 1)
                        )
                        .shadow(color: Color(hexToken: tokens.primary).opacity(0.06), radius: 12, x: 0, y: 6)

                    if let translation = entry.translation {
                        Text(translation)
                            .font(.body)
                            .foregroundStyle(Color(hexToken: tokens.onSurface))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .brandCard(tokens)
                    }

                    if let benefitNote = entry.benefitNote {
                        VStack(alignment: .trailing, spacing: 6) {
                            Label("hadith.benefit_label", systemImage: "lightbulb.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color(hexToken: tokens.accent))
                            Text(benefitNote)
                                .font(.subheadline)
                                .foregroundStyle(Color(hexToken: tokens.onSurface))
                                .multilineTextAlignment(.trailing)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(16)
                        .background(Color(hexToken: tokens.accent).opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color(hexToken: tokens.accent).opacity(0.3), lineWidth: 1)
                        )
                    }

                    if !entry.source.isEmpty {
                        Text(entry.source)
                            .font(.caption)
                            .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .padding(20)
            }

            HStack(spacing: 12) {
                Button("hadith.previous") { viewModel.previous() }
                    .buttonStyle(.bordered)
                    .tint(Color(hexToken: tokens.primary))
                    .controlSize(.large)
                    .disabled(isAtFirst)
                Button("hadith.next") { viewModel.next() }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(hexToken: tokens.primary))
                    .controlSize(.large)
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
