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
        VStack(spacing: 20) {
            countHeader
            presetChips
            Spacer()
            tapTarget
            Spacer()
            controls
        }
        .padding()
        .background(Color(hexToken: tokens.surface))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showHistory = true
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                }
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

    private var countHeader: some View {
        VStack(spacing: 4) {
            Text("\(viewModel.count)")
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color(hexToken: tokens.primary))
                .contentTransition(.numericText())
                .animation(.snappy, value: viewModel.count)
            Text("tasbeeh.target \(viewModel.target)")
                .font(.subheadline)
                .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
        }
    }

    @ViewBuilder
    private var presetChips: some View {
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
        }
        if viewModel.selectedPreset.id == DhikrPreset.custom.id {
            TextField("tasbeeh.custom_placeholder", text: $viewModel.customText)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
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

    private var tapTarget: some View {
        Button {
            viewModel.increment()
        } label: {
            Circle()
                .fill(Color(hexToken: tokens.primary))
                .overlay {
                    Text(viewModel.displayText)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Color(hexToken: tokens.onPrimary))
                        .padding()
                        .minimumScaleFactor(0.5)
                }
                .frame(width: 220, height: 220)
                .shadow(radius: viewModel.justReachedTarget ? 12 : 4)
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

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        statColumn(value: stats.totalCount, labelKey: "tasbeeh.stats.total")
                        statColumn(value: stats.setsCompleted, labelKey: "tasbeeh.stats.sets")
                    }
                }
                Section {
                    ForEach(history.sorted(by: { $0.completedAt > $1.completedAt })) { entry in
                        HStack {
                            Text(entry.customText ?? entry.presetId ?? "")
                            Spacer()
                            Text("\(entry.actualCount)/\(entry.target)").monospacedDigit()
                        }
                    }
                }
            }
            .navigationTitle(Text("tasbeeh.history_title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.done") { dismiss() }
                }
            }
        }
    }

    private func statColumn(value: Int, labelKey: LocalizedStringKey) -> some View {
        VStack {
            Text("\(value)").font(.title.weight(.bold)).monospacedDigit()
            Text(labelKey).font(.caption)
        }
        .frame(maxWidth: .infinity)
    }
}
