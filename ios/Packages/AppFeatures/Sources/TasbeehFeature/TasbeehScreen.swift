import DesignSystemKit
import SwiftUI

public struct TasbeehScreen: View {
    @State private var viewModel: TasbeehViewModel
    @State private var showResetConfirmation = false
    @State private var showHistory = false
    @Environment(\.colorScheme) private var colorScheme

    public init(viewModel: TasbeehViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    private var tokens: ColorTokens {
        let base = DesignTokens.bundledDefault
        return colorScheme == .dark ? base.dark : base.light
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                presetChips
                tapTarget
                controls
            }
            .padding(20)
        }
        .brandScreenBackground(tokens)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showHistory = true
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                }
                .accessibilityLabel(Text("tasbeeh.history_title"))
            }
        }
        .sheet(isPresented: $showHistory) {
            TasbeehHistoryView(stats: viewModel.stats, history: viewModel.history)
        }
        .confirmationDialog(
            Text("tasbeeh.reset_confirm_title"),
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button(role: .destructive) {
                viewModel.reset()
            } label: {
                Text("tasbeeh.reset_confirm_action")
            }
        }
    }

    @ScaledMetric(relativeTo: .largeTitle) private var countFontSize: CGFloat = 64

    /// Fraction of the current target reached (clamped to 1 past target) — drives the ring.
    private var progressFraction: Double {
        viewModel.target > 0 ? min(Double(viewModel.count) / Double(viewModel.target), 1) : 0
    }

    @ViewBuilder
    private var presetChips: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DhikrPreset.bundled) { preset in
                        chip(title: preset.arabicText, isSelected: viewModel.selectedPreset.id == preset.id) {
                            viewModel.select(preset: preset)
                        }
                    }
                    chip(
                        title: String(localized: "tasbeeh.custom"),
                        isSelected: viewModel.selectedPreset.id == DhikrPreset.custom.id
                    ) {
                        viewModel.select(preset: .custom)
                    }
                }
                .padding(.horizontal, 2)
            }
            if viewModel.selectedPreset.id == DhikrPreset.custom.id {
                TextField("tasbeeh.custom_placeholder", text: $viewModel.customText)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private func chip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
                .background(
                    isSelected ? Color(hexToken: tokens.primary) : Color(hexToken: tokens.primaryContainer),
                    in: Capsule()
                )
                .foregroundStyle(isSelected ? Color(hexToken: tokens.onPrimary) : Color(hexToken: tokens.primary))
        }
        .buttonStyle(.plain)
    }

    /// The centerpiece: a big circular tap target with a progress ring around
    /// the live count and the selected dhikr text beneath it.
    private var tapTarget: some View {
        Button {
            viewModel.increment()
        } label: {
            ZStack {
                RingProgress(value: progressFraction, lineWidth: 12, tokens: tokens)
                    .motionAnimation(.snappy, value: progressFraction)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hexToken: tokens.primaryContainer),
                                Color(hexToken: tokens.surfaceElevated),
                            ],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .padding(18)

                VStack(spacing: 8) {
                    Text("\(viewModel.count)")
                        .font(.system(size: countFontSize, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Color(hexToken: tokens.primary))
                        .contentTransition(.numericText())
                        .motionAnimation(.snappy, value: viewModel.count)

                    Text(viewModel.displayText)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color(hexToken: tokens.onSurface))
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.5)
                        .lineLimit(2)
                        .padding(.horizontal, 24)

                    Text("tasbeeh.target \(viewModel.target)")
                        .font(.subheadline)
                        .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                        .monospacedDigit()
                }
                .padding(28)
            }
            .frame(width: 300, height: 300)
            .shadow(color: Color(hexToken: tokens.primary).opacity(viewModel.justReachedTarget ? 0.35 : 0.12),
                    radius: viewModel.justReachedTarget ? 22 : 14, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.success, trigger: viewModel.justReachedTarget) { _, new in new }
        .accessibilityLabel(Text("tasbeeh.tap_target_a11y"))
        .accessibilityValue(Text("\(viewModel.count)"))
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button {
                if viewModel.count > 0 {
                    showResetConfirmation = true
                } else {
                    viewModel.reset()
                }
            } label: {
                Text("common.reset").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Menu {
                ForEach(DhikrPreset.commonTargets, id: \.self) { value in
                    Button("\(value)") { viewModel.changeTarget(value) }
                }
            } label: {
                Text("tasbeeh.target \(viewModel.target)").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button {
                viewModel.completeSet()
            } label: {
                Text("tasbeeh.complete_set").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.count == 0)
        }
    }
}

struct TasbeehHistoryView: View {
    let stats: TasbeehStats
    let history: [TasbeehHistoryEntry]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var tokens: ColorTokens {
        let base = DesignTokens.bundledDefault
        return colorScheme == .dark ? base.dark : base.light
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 14) {
                        statCard(value: stats.totalCount, labelKey: "tasbeeh.stats.total")
                        statCard(value: stats.setsCompleted, labelKey: "tasbeeh.stats.sets")
                    }

                    if history.isEmpty {
                        BrandEmptyState(systemImage: "list.bullet.rectangle", messageKey: "tasbeeh.history_empty", tokens: tokens)
                    } else {
                        VStack(spacing: 0) {
                            let entries = history.sorted(by: { $0.completedAt > $1.completedAt })
                            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                                HStack {
                                    Text(entry.customText ?? entry.presetId ?? "")
                                        .foregroundStyle(Color(hexToken: tokens.onSurface))
                                    Spacer()
                                    Text("\(entry.actualCount)/\(entry.target)")
                                        .font(.body.monospacedDigit())
                                        .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                                }
                                .padding(.vertical, 12)
                                if index < entries.count - 1 {
                                    Divider().opacity(0.3)
                                }
                            }
                        }
                        .brandCard(tokens)
                    }
                }
                .padding(20)
            }
            .brandScreenBackground(tokens)
            .navigationTitle(Text("tasbeeh.history_title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.done") { dismiss() }
                }
            }
        }
    }

    private func statCard(value: Int, labelKey: LocalizedStringKey) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color(hexToken: tokens.primary))
            Text(labelKey)
                .font(.caption)
                .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(hexToken: tokens.surfaceElevated), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color(hexToken: tokens.outline).opacity(0.6), lineWidth: 1)
        )
        .shadow(color: Color(hexToken: tokens.primary).opacity(0.05), radius: 8, x: 0, y: 3)
    }
}
