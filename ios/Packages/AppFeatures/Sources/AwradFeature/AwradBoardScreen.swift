import ContentKit
import DesignSystemKit
import SwiftUI

/// Daily checklist (docs/features/awrad.md screen 1).
public struct AwradBoardScreen: View {
    @State private var viewModel: AwradViewModel
    @State private var showCreateSheet = false
    @State private var showStats = false
    @Environment(\.colorScheme) private var colorScheme
    private let locale: String

    public init(viewModel: AwradViewModel, locale: String = "ar") {
        _viewModel = State(initialValue: viewModel)
        self.locale = locale
    }

    private var tokens: ColorTokens {
        colorScheme == .dark ? DesignTokens.bundledDefault.dark : DesignTokens.bundledDefault.light
    }

    public var body: some View {
        Group {
            if viewModel.wirds.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(viewModel.activeWirds) { wird in
                        wirdRow(wird)
                    }
                    Section {
                        Button("awrad.mark_day_complete") {
                            _ = viewModel.markDayComplete()
                        }
                        .disabled(viewModel.isDayCompletedToday)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showStats = true } label: { Image(systemName: "chart.bar") }
            }
            ToolbarItem(placement: .primaryAction) {
                Button { showCreateSheet = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            AwradCreateSheet(viewModel: viewModel, locale: locale)
        }
        .sheet(isPresented: $showStats) {
            AwradStatsView(stats: viewModel.stats)
        }
        .task { await viewModel.loadTemplates(locale: locale) }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "leaf")
                .font(.system(size: 40))
                .foregroundStyle(Color(hexToken: tokens.primary))
            Text("awrad.empty_title")
                .font(.headline)
            Text("awrad.empty_subtitle")
                .font(.subheadline)
                .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                .multilineTextAlignment(.center)
            Button("awrad.add_first_wird") { showCreateSheet = true }
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func wirdRow(_ wird: Wird) -> some View {
        let count = viewModel.todayCount(for: wird.id)
        return HStack {
            VStack(alignment: .leading) {
                Text(wird.name)
                Text("\(count)/\(wird.target)")
                    .font(.caption)
                    .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
            }
            Spacer()
            Button {
                viewModel.tick(wirdId: wird.id)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color(hexToken: tokens.primary))
            }
            .buttonStyle(.plain)
        }
    }
}

struct AwradStatsView: View {
    let stats: WirdStats
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                stat("awrad.stats.total_dhikr", stats.totalDhikrCount)
                stat("awrad.stats.completed_days", stats.completedDaysCount)
                stat("awrad.stats.quran_pages", stats.quranPagesCount)
                stat("awrad.stats.salawat", stats.salawatCount)
            }
            .navigationTitle(Text("awrad.stats_title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.done") { dismiss() }
                }
            }
        }
    }

    private func stat(_ titleKey: LocalizedStringKey, _ value: Int) -> some View {
        HStack {
            Text(titleKey)
            Spacer()
            Text("\(value)").monospacedDigit().foregroundStyle(.secondary)
        }
    }
}
