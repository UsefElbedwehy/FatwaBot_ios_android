import ContentKit
import DesignSystemKit
import SwiftUI

/// Library browse/search home (docs/features/dua.md screen 1).
public struct DuaLibraryScreen: View {
    @State private var viewModel: DuaViewModel
    @Environment(\.colorScheme) private var colorScheme
    private let locale: String

    public init(viewModel: DuaViewModel, locale: String = "ar") {
        _viewModel = State(initialValue: viewModel)
        self.locale = locale
    }

    private var tokens: ColorTokens {
        colorScheme == .dark ? DesignTokens.bundledDefault.dark : DesignTokens.bundledDefault.light
    }

    public var body: some View {
        List {
            searchField

            if let results = viewModel.searchResults {
                searchResultsSection(results)
            } else {
                if !viewModel.favoriteDuas.isEmpty {
                    Section("dua.favorites") {
                        ForEach(viewModel.favoriteDuas) { dua in
                            NavigationLink { DuaReadingScreen(viewModel: viewModel, dua: dua) } label: { row(dua) }
                        }
                    }
                }
                ForEach(viewModel.categories) { category in
                    Section(category.name) {
                        ForEach(category.duas) { dua in
                            NavigationLink { DuaReadingScreen(viewModel: viewModel, dua: dua) } label: { row(dua) }
                        }
                    }
                }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
        .task { await viewModel.loadCategories(locale: locale) }
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
            TextField("dua.search_placeholder", text: $viewModel.searchQuery)
        }
    }

    @ViewBuilder
    private func searchResultsSection(_ results: [Dua]) -> some View {
        if results.isEmpty {
            Section {
                Text("dua.search_no_results")
                    .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
            }
        } else {
            Section("dua.search_results") {
                ForEach(results) { dua in
                    NavigationLink { DuaReadingScreen(viewModel: viewModel, dua: dua) } label: { row(dua) }
                }
            }
        }
    }

    private func row(_ dua: Dua) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(dua.title).font(.body)
            if !dua.source.isEmpty {
                Text(dua.source)
                    .font(.caption)
                    .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}
