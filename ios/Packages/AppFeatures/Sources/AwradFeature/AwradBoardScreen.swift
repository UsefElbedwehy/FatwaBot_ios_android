import ContentKit
import DesignSystemKit
import SwiftUI

/// Daily checklist (docs/features/awrad.md screen 1).
public struct AwradBoardScreen: View {
    @State private var viewModel: AwradViewModel
    @State private var showCreateSheet = false
    @State private var showStats = false
    @State private var editingWird: Wird?
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    private let locale: String

    public init(viewModel: AwradViewModel, locale: String = "ar") {
        _viewModel = State(initialValue: viewModel)
        self.locale = locale
    }

    private var tokens: ColorTokens {
        colorScheme == .dark ? DesignTokens.bundledDefault.dark : DesignTokens.bundledDefault.light
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if viewModel.wirds.isEmpty {
                    emptyState
                } else {
                    statsGrid

                    VStack(alignment: .leading, spacing: 12) {
                        BrandSectionHeader("worship.awrad", systemImage: "leaf.fill", tokens: tokens)
                        VStack(spacing: 12) {
                            ForEach(viewModel.activeWirds) { wird in
                                wirdCard(wird)
                            }
                        }
                    }

                    markDayCompleteCard
                }
            }
            .padding(20)
        }
        .brandScreenBackground(tokens)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showStats = true } label: { Image(systemName: "chart.bar") }
                    .accessibilityLabel(Text("awrad.stats_title"))
            }
            ToolbarItem(placement: .primaryAction) {
                Button { showCreateSheet = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel(Text("awrad.add_first_wird"))
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            AwradCreateSheet(viewModel: viewModel, locale: locale)
        }
        .sheet(isPresented: $showStats) {
            AwradStatsView(stats: viewModel.stats)
        }
        .sheet(item: $editingWird) { wird in
            WirdTargetSheet(wird: wird) { newTarget in
                viewModel.setTarget(wirdId: wird.id, target: newTarget)
            }
        }
        .task {
            // Picks up anything a notification "yes" wrote while the app was
            // backgrounded (see WirdCompletionResponder).
            viewModel.reload()
            await viewModel.loadTemplates(locale: locale)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { viewModel.reload() }
        }
    }

    // MARK: - Stats

    private var statsGrid: some View {
        let stats = viewModel.stats
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            StatTile(titleKey: "awrad.stats.total_dhikr", value: stats.totalDhikrCount, systemImage: "circle.hexagonpath.fill", tokens: tokens)
            StatTile(titleKey: "awrad.stats.completed_days", value: stats.completedDaysCount, systemImage: "checkmark.seal.fill", tokens: tokens)
            StatTile(titleKey: "awrad.stats.quran_pages", value: stats.quranPagesCount, systemImage: "book.fill", tokens: tokens)
            StatTile(titleKey: "awrad.stats.salawat", value: stats.salawatCount, systemImage: "heart.fill", tokens: tokens)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                ArchIconBadge(systemImage: "leaf", tokens: tokens)
                Text("awrad.empty_title")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color(hexToken: tokens.onSurface))
                Text("awrad.empty_subtitle")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
            }
            Button("awrad.add_first_wird") { showCreateSheet = true }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [Color(hexToken: tokens.primary), Color(hexToken: tokens.accent)],
                        startPoint: .leading, endPoint: .trailing
                    ),
                    in: Capsule()
                )
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    // MARK: - Wird card

    private func wirdCard(_ wird: Wird) -> some View {
        let count = viewModel.todayCount(for: wird.id)
        let fraction = wird.target > 0 ? Double(count) / Double(wird.target) : 0
        let reached = count >= wird.target
        return HStack(spacing: 14) {
            ZStack {
                RingProgress(value: fraction, lineWidth: 6, tokens: tokens)
                    .motionAnimation(.easeOut(duration: MotionTokens.quickDuration), value: count)
                if reached {
                    Image(systemName: "checkmark")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color(hexToken: tokens.accent))
                } else {
                    Text("\(count)")
                        .font(.callout.weight(.bold).monospacedDigit())
                        .foregroundStyle(Color(hexToken: tokens.primary))
                        .contentTransition(.numericText())
                        .motionAnimation(.easeOut(duration: MotionTokens.quickDuration), value: count)
                }
            }
            .frame(width: 52, height: 52)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                // Name first, badge under it. Inline, the badge stole width from
                // the title and forced names like "Night Prayer (Qiyam)" to wrap
                // across three lines with the badge floating beside the middle
                // one. The name is what the user reads; it gets the full width.
                Text(wird.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color(hexToken: tokens.onSurface))
                    .fixedSize(horizontal: false, vertical: true)
                // The only thing marking a fixed slot apart: it is one of the
                // four everyone has. No delete affordance is drawn for it —
                // and none is drawn for user wirds either, so its absence is
                // not what distinguishes them.
                if wird.isFixed { fixedBadge }
                Text("\(count)/\(wird.target)")
                    .font(.caption)
                    .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                    .contentTransition(.numericText())
                    .motionAnimation(.easeOut(duration: MotionTokens.quickDuration), value: count)
            }
            .accessibilityElement(children: .combine)

            Spacer(minLength: 8)

            Button {
                editingWird = wird
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.body)
                    .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("awrad.edit_target"))

            Button {
                viewModel.tick(wirdId: wird.id)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title)
                    .foregroundStyle(Color(hexToken: tokens.primary))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(wird.name))
            .accessibilityHint(Text("azkar.tap_to_count"))
        }
        .brandCard(tokens)
    }

    private var fixedBadge: some View {
        Text("awrad.fixed_badge")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Color(hexToken: tokens.primary))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Color(hexToken: tokens.primaryContainer), in: Capsule())
    }

    // MARK: - Mark day complete

    private var markDayCompleteCard: some View {
        let done = viewModel.isDayCompletedToday
        return Button {
            _ = viewModel.markDayComplete()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: done ? "checkmark.seal.fill" : "seal")
                    .font(.title3)
                Text("awrad.mark_day_complete")
                    .font(.body.weight(.semibold))
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            .padding(.vertical, 16)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [Color(hexToken: tokens.primary), Color(hexToken: tokens.accent)],
                    startPoint: .leading, endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .shadow(color: Color(hexToken: tokens.primary).opacity(0.18), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(done)
        .opacity(done ? 0.55 : 1)
    }
}

/// Premium stat tile — a stacked icon + big number + label in an elevated card.
private struct StatTile: View {
    let titleKey: LocalizedStringKey
    let value: Int
    let systemImage: String
    let tokens: ColorTokens

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                Circle().fill(Color(hexToken: tokens.primaryContainer))
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(hexToken: tokens.primary))
            }
            .frame(width: 34, height: 34)
            .accessibilityHidden(true)

            Text("\(value)")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color(hexToken: tokens.onSurface))
            Text(titleKey)
                .font(.caption)
                .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard(tokens)
        .accessibilityElement(children: .combine)
    }
}

/// Retargeting, the one edit a fixed slot allows (and a plain one allows too).
/// The name is deliberately not editable: the four fixed slots are named by the
/// product, and no wird has ever been renameable here.
struct WirdTargetSheet: View {
    let wird: Wird
    let onSave: (Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var targetText: String

    init(wird: Wird, onSave: @escaping (Int) -> Void) {
        self.wird = wird
        self.onSave = onSave
        _targetText = State(initialValue: "\(wird.target)")
    }

    private var tokens: ColorTokens {
        colorScheme == .dark ? DesignTokens.bundledDefault.dark : DesignTokens.bundledDefault.light
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(wird.name)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color(hexToken: tokens.onSurface))

                targetField

                Button("awrad.save_custom") {
                    onSave(Int(targetText) ?? wird.target)
                    dismiss()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    LinearGradient(
                        colors: [Color(hexToken: tokens.primary), Color(hexToken: tokens.accent)],
                        startPoint: .leading, endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )

                Spacer()
            }
            .padding(20)
            .brandScreenBackground(tokens)
            .navigationTitle(Text("awrad.edit_target"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
            }
        }
    }

    private var targetField: some View {
        let field = TextField("awrad.custom_target_placeholder", text: $targetText)
            .font(.body)
            .foregroundStyle(Color(hexToken: tokens.onSurface))
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(hexToken: tokens.surface), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(hexToken: tokens.outline).opacity(0.7), lineWidth: 1)
            )
        #if os(iOS)
        return field.keyboardType(.numberPad)
        #else
        return field
        #endif
    }
}

struct AwradStatsView: View {
    let stats: WirdStats
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var tokens: ColorTokens {
        colorScheme == .dark ? DesignTokens.bundledDefault.dark : DesignTokens.bundledDefault.light
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    stat("awrad.stats.total_dhikr", stats.totalDhikrCount, systemImage: "circle.hexagonpath.fill")
                    stat("awrad.stats.completed_days", stats.completedDaysCount, systemImage: "checkmark.seal.fill")
                    stat("awrad.stats.quran_pages", stats.quranPagesCount, systemImage: "book.fill")
                    stat("awrad.stats.salawat", stats.salawatCount, systemImage: "heart.fill")
                }
                .padding(20)
            }
            .brandScreenBackground(tokens)
            .navigationTitle(Text("awrad.stats_title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.done") { dismiss() }
                }
            }
        }
    }

    private func stat(_ titleKey: LocalizedStringKey, _ value: Int, systemImage: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color(hexToken: tokens.primaryContainer))
                Image(systemName: systemImage)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color(hexToken: tokens.primary))
            }
            .frame(width: 40, height: 40)
            .accessibilityHidden(true)
            Text(titleKey)
                .font(.body.weight(.medium))
                .foregroundStyle(Color(hexToken: tokens.onSurface))
            Spacer()
            Text("\(value)")
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(Color(hexToken: tokens.primary))
        }
        .brandCard(tokens)
        .accessibilityElement(children: .combine)
    }
}
