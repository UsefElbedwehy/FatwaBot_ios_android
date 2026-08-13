import ContentKit
import DesignSystemKit
import SwiftUI

/// Daily checklist (docs/features/awrad.md screen 1).
public struct AwradBoardScreen: View {
    @State private var viewModel: AwradViewModel
    @State private var editingWird: Wird?
    @State private var wirdPendingDelete: Wird?
    @State private var showCreateSheet = false
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

    /// Whether "أضف ورد اليوم" would actually add anything right now — hides
    /// the menu item once all four are already active, rather than offering an
    /// action that's a silent no-op.
    private var hasAllFixedSlots: Bool {
        FixedWirdSlot.allCases.allSatisfy { slot in
            viewModel.activeWirds.contains { $0.id == slot.wirdId }
        }
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if viewModel.activeWirds.isEmpty {
                    emptyState
                } else {
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
                Menu {
                    if !hasAllFixedSlots {
                        Button {
                            viewModel.addTodaysWird()
                        } label: {
                            Label("awrad.add_today", systemImage: "leaf")
                        }
                    }
                    Button {
                        showCreateSheet = true
                    } label: {
                        Label("awrad.create_custom", systemImage: "plus.circle")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(item: $editingWird) { wird in
            WirdTargetSheet(wird: wird) { newTarget in
                viewModel.setTarget(wirdId: wird.id, target: newTarget)
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            AwradCreateSheet(viewModel: viewModel, locale: locale)
        }
        .confirmationDialog(
            Text("awrad.delete_confirm_title"),
            isPresented: Binding(
                get: { wirdPendingDelete != nil },
                set: { if !$0 { wirdPendingDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: wirdPendingDelete
        ) { wird in
            Button("awrad.delete_confirm_action", role: .destructive) {
                viewModel.deleteWird(wird.id)
                wirdPendingDelete = nil
            }
            Button("common.cancel", role: .cancel) { wirdPendingDelete = nil }
        } message: { wird in
            Text(wird.name)
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

            VStack(spacing: 10) {
                Button("awrad.add_today") { viewModel.addTodaysWird() }
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

                Button("awrad.create_custom") { showCreateSheet = true }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(hexToken: tokens.primary))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
            }
            .frame(maxWidth: 320)
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
                Text("\(count)/\(wird.target)")
                    .font(.caption)
                    .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                    .contentTransition(.numericText())
                    .motionAnimation(.easeOut(duration: MotionTokens.quickDuration), value: count)
            }
            .accessibilityElement(children: .combine)

            Spacer(minLength: 8)

            Button {
                wirdPendingDelete = wird
            } label: {
                Image(systemName: "trash")
                    .font(.body)
                    .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("awrad.delete"))

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
