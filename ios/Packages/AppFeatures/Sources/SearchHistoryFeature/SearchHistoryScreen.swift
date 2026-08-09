import DesignSystemKit
import SwiftUI

public struct SearchHistoryScreen: View {
    @State private var viewModel: SearchHistoryViewModel
    @State private var showingClearConfirmation = false
    @Environment(\.colorScheme) private var colorScheme

    public init(viewModel: SearchHistoryViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    private var tokens: ColorTokens {
        let base = DesignTokens.bundledDefault
        return colorScheme == .dark ? base.dark : base.light
    }

    private var groupedByDay: [(day: Date, entries: [SearchHistoryEntry])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: viewModel.entries) { calendar.startOfDay(for: $0.createdAt) }
        return groups.keys.sorted(by: >).map { day in (day, groups[day]!.sorted { $0.createdAt > $1.createdAt }) }
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let error = viewModel.error {
                    HStack(spacing: 10) {
                        Image(systemName: "wifi.exclamationmark").foregroundStyle(Color(hexToken: tokens.accent))
                        Text(error).font(.footnote).foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                    }
                    .brandCard(tokens)
                }

                ForEach(groupedByDay, id: \.day) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        BrandSectionHeader(
                            LocalizedStringKey(group.day.formatted(date: .abbreviated, time: .omitted)),
                            systemImage: "calendar",
                            tokens: tokens
                        )
                        VStack(spacing: 0) {
                            ForEach(Array(group.entries.enumerated()), id: \.element.id) { index, entry in
                                HStack(spacing: 12) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.footnote)
                                        .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                                    Text(entry.queryText)
                                        .foregroundStyle(Color(hexToken: tokens.onSurface))
                                    Spacer(minLength: 8)
                                    Button {
                                        Task { await viewModel.delete(entry) }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary).opacity(0.6))
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(Text("common.delete"))
                                }
                                .padding(.vertical, 12)
                                if index < group.entries.count - 1 {
                                    Divider().opacity(0.3)
                                }
                            }
                        }
                        .brandCard(tokens, padding: 16)
                    }
                }

                if !viewModel.isLoading && viewModel.entries.isEmpty && viewModel.error == nil {
                    BrandEmptyState(systemImage: "clock.arrow.circlepath", messageKey: "search_history.empty_state", tokens: tokens)
                }
            }
            .padding(20)
        }
        .brandScreenBackground(tokens)
        .overlay {
            if viewModel.isLoading && viewModel.entries.isEmpty {
                ProgressView().tint(Color(hexToken: tokens.primary))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .navigationTitle(Text("search_history.title"))
        .toolbar {
            if !viewModel.entries.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button("search_history.clear_all") { showingClearConfirmation = true }
                }
            }
        }
        .confirmationDialog(
            Text("search_history.clear_all_confirm_title"),
            isPresented: $showingClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("search_history.clear_all", role: .destructive) {
                Task { await viewModel.clearAll() }
            }
            Button("common.cancel", role: .cancel) {}
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }
}
