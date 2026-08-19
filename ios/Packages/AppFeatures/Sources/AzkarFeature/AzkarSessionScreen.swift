import ContentKit
import DesignSystemKit
import CoreKit
import SwiftUI

/// The reading/counting session (docs/features/azkar.md screen 2). Completion
/// is a calm confirmation, not a celebratory burst — azkar is worship, not a
/// game (ADR-0007 tone guidance).
public struct AzkarSessionScreen: View {
    @State private var viewModel: AzkarViewModel
    @Environment(\.colorScheme) private var colorScheme
    private let category: AzkarCategory

    public init(viewModel: AzkarViewModel, category: AzkarCategory) {
        _viewModel = State(initialValue: viewModel)
        self.category = category
    }

    private var tokens: ColorTokens {
        colorScheme == .dark ? DesignTokens.bundledDefault.dark : DesignTokens.bundledDefault.light
    }

    public var body: some View {
        Group {
            if viewModel.isSessionComplete {
                completionView
            } else if let item = viewModel.currentItem {
                sessionView(item: item)
            } else {
                ProgressView()
                    .tint(Color(hexToken: tokens.primary))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .brandScreenBackground(tokens)
        .navigationTitle(Text(category.name))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            // The view model is shared across categories, so a finished session
            // must not leak its state onto the next category opened: always
            // re-initialise when this screen is for a different category.
            // (Guarding only on `!isSessionComplete` made every category opened
            // after a completed one render as already-completed.)
            if viewModel.categoryId != category.id
                || (viewModel.currentItem == nil && !viewModel.isSessionComplete) {
                viewModel.startSession(categoryId: category.id, items: category.items)
            }
        }
    }

    private func sessionView(item: AzkarItem) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                progressCard

                // Arabic dhikr — the prominent centerpiece card.
                BrandCard(tokens, padding: 22) {
                    VStack(alignment: .trailing, spacing: 16) {
                        Text(item.arabicText.expandingArabicHonorifics)
                            .font(.title.weight(.medium))
                            .foregroundStyle(Color(hexToken: tokens.onSurface))
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: .infinity, alignment: .trailing)

                        if let translation = item.translation {
                            Divider()
                                .overlay(Color(hexToken: tokens.outline))
                            Text(translation)
                                .font(.body)
                                .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .multilineTextAlignment(.leading)
                        }

                        if !item.source.isEmpty {
                            Text(item.source)
                                .font(.caption)
                                .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                }

                // Virtue / benefit note — a subtle, warm accented card.
                if let virtueNote = item.virtueNote {
                    virtueCard(virtueNote)
                }

                // The counter — large, calm, tappable ring.
                counter(item: item)
                    .padding(.top, 4)
            }
            .padding(20)
        }
    }

    private var progressCard: some View {
        VStack(spacing: 8) {
            ProgressView(value: viewModel.progress)
                .tint(Color(hexToken: tokens.primary))
        }
        .padding(.horizontal, 4)
    }

    private func virtueCard(_ virtueNote: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "sparkles")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(hexToken: tokens.accent))
                .accessibilityHidden(true)
            VStack(alignment: .trailing, spacing: 4) {
                Text("azkar.virtue_note_label")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(hexToken: tokens.primary))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                Text(virtueNote)
                    .font(.subheadline)
                    .foregroundStyle(Color(hexToken: tokens.onSurface))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(16)
        .background(
            Color(hexToken: tokens.primaryContainer),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color(hexToken: tokens.accent).opacity(0.25), lineWidth: 1)
        )
    }

    private func counter(item: AzkarItem) -> some View {
        let fraction = item.repeatCount > 0
            ? Double(viewModel.currentItemCount) / Double(item.repeatCount)
            : 0

        return Button {
            viewModel.tick()
        } label: {
            ZStack {
                RingProgress(value: fraction, lineWidth: 12, tokens: tokens)
                    .motionAnimation(.easeOut(duration: MotionTokens.quickDuration), value: viewModel.currentItemCount)

                Circle()
                    .fill(Color(hexToken: tokens.primary).opacity(0.06))
                    .padding(18)

                VStack(spacing: 4) {
                    Text("\(viewModel.currentItemCount)/\(item.repeatCount)")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.5)
                        .contentTransition(.numericText())
                        .motionAnimation(.easeOut(duration: MotionTokens.quickDuration), value: viewModel.currentItemCount)
                        .foregroundStyle(Color(hexToken: tokens.primary))
                    Text("azkar.tap_to_count")
                        .font(.caption)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                }
                .padding(8)
            }
            .frame(width: 220, height: 220)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("azkar.tap_to_count"))
        .accessibilityValue(Text("\(viewModel.currentItemCount) \(item.repeatCount)"))
    }

    private var completionView: some View {
        VStack(spacing: 20) {
            ArchIconBadge(systemImage: "checkmark", tokens: tokens)
            Text("azkar.session_complete")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color(hexToken: tokens.onSurface))
            Text("azkar.session_complete_subtitle")
                .font(.subheadline)
                .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
