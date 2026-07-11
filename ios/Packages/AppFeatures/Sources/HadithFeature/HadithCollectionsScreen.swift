import ContentKit
import DesignSystemKit
import SwiftUI

/// Collections browser (docs/features/hadith-collections.md screen 1).
public struct HadithCollectionsScreen: View {
    @State private var viewModel: HadithViewModel
    @Environment(\.colorScheme) private var colorScheme
    private let locale: String

    public init(viewModel: HadithViewModel, locale: String = "ar") {
        _viewModel = State(initialValue: viewModel)
        self.locale = locale
    }

    private var tokens: ColorTokens {
        colorScheme == .dark ? DesignTokens.bundledDefault.dark : DesignTokens.bundledDefault.light
    }

    public var body: some View {
        Group {
            if viewModel.collections.isEmpty {
                if viewModel.isLoadingCollections {
                    ProgressView()
                        .tint(Color(hexToken: tokens.primary))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    BrandEmptyState(systemImage: "text.book.closed", messageKey: "hadith.empty_state", tokens: tokens)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                ScrollView {
                    VStack(spacing: 14) {
                        ForEach(viewModel.collections) { collection in
                            NavigationLink {
                                HadithReadingScreen(viewModel: viewModel, slug: collection.slug, locale: locale)
                                    .navigationTitle(Text(collection.name))
                                    #if os(iOS)
                                    .navigationBarTitleDisplayMode(.inline)
                                    #endif
                            } label: {
                                row(collection)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                }
            }
        }
        .brandScreenBackground(tokens)
        .motionAnimation(.easeInOut(duration: MotionTokens.standardDuration), value: viewModel.collections.isEmpty)
        .task { await viewModel.loadCollections(locale: locale) }
    }

    private func row(_ collection: HadithCollectionSummary) -> some View {
        let read = viewModel.readCount(forSlug: collection.slug)
        let completed = viewModel.isCompleted(slug: collection.slug, totalEntries: collection.entryCount)
        let fraction = collection.entryCount > 0 ? Double(read) / Double(collection.entryCount) : 0
        return HStack(spacing: 14) {
            ZStack {
                RingProgress(value: fraction, lineWidth: 5, tokens: tokens)
                Image(systemName: completed ? "checkmark" : "book.closed.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color(hexToken: completed ? tokens.accent : tokens.primary))
            }
            .frame(width: 44, height: 44)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(collection.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color(hexToken: tokens.onSurface))
                Text("hadith.progress_read \(read) \(collection.entryCount)")
                    .font(.caption)
                    .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.forward")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary).opacity(0.7))
        }
        .brandCard(tokens)
        .accessibilityElement(children: .combine)
    }
}
