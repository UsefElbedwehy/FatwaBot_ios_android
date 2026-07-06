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
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.collections) { collection in
                    NavigationLink {
                        HadithReadingScreen(viewModel: viewModel, slug: collection.slug, locale: locale)
                            .navigationTitle(Text(collection.name))
                            #if os(iOS)
                            .navigationBarTitleDisplayMode(.inline)
                            #endif
                    } label: {
                        row(collection)
                    }
                }
            }
        }
        .task { await viewModel.loadCollections(locale: locale) }
    }

    private func row(_ collection: HadithCollectionSummary) -> some View {
        let read = viewModel.readCount(forSlug: collection.slug)
        let completed = viewModel.isCompleted(slug: collection.slug, totalEntries: collection.entryCount)
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(collection.name).font(.body)
                Text("hadith.progress_read \(read) \(collection.entryCount)")
                    .font(.caption)
                    .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
            }
            Spacer()
            if completed {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color(hexToken: tokens.primary))
            }
        }
    }
}
