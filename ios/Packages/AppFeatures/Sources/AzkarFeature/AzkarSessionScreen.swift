import ContentKit
import DesignSystemKit
import SwiftUI

/// The reading/counting session (docs/features/azkar.md screen 2). Completion
/// is a calm confirmation, not a celebratory burst — azkar is worship, not a
/// game (ADR-0007 tone guidance).
public struct AzkarSessionScreen: View {
    @State private var viewModel: AzkarViewModel
    @State private var showTranslation = true
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
            }
        }
        .background(Color(hexToken: tokens.surface))
        .navigationTitle(Text(category.name))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            if viewModel.currentItem == nil, !viewModel.isSessionComplete {
                viewModel.startSession(categoryId: category.id, items: category.items)
            }
        }
    }

    private func sessionView(item: AzkarItem) -> some View {
        VStack(spacing: 20) {
            ProgressView(value: viewModel.progress)
                .tint(Color(hexToken: tokens.primary))
                .padding(.horizontal)

            ScrollView {
                VStack(alignment: .trailing, spacing: 16) {
                    Text(item.arabicText)
                        .font(.title.weight(.medium))
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    if showTranslation, let translation = item.translation {
                        Text(translation)
                            .font(.body)
                            .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                    }

                    if let virtueNote = item.virtueNote {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("azkar.virtue_note_label")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color(hexToken: tokens.primary))
                            Text(virtueNote)
                                .font(.subheadline)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding()
                        .background(Color(hexToken: tokens.primaryContainer), in: RoundedRectangle(cornerRadius: 14))
                    }

                    if !item.source.isEmpty {
                        Text(item.source)
                            .font(.caption)
                            .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .padding()
            }

            Spacer()

            Button {
                viewModel.tick()
            } label: {
                VStack(spacing: 4) {
                    Text("\(viewModel.currentItemCount)/\(item.repeatCount)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("azkar.tap_to_count")
                        .font(.caption)
                }
                .foregroundStyle(Color(hexToken: tokens.onPrimary))
                .frame(width: 180, height: 180)
                .background(Color(hexToken: tokens.primary), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("azkar.tap_to_count"))
            .accessibilityValue(Text("\(viewModel.currentItemCount) \(item.repeatCount)"))
            .padding(.bottom, 24)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showTranslation.toggle()
                } label: {
                    Image(systemName: showTranslation ? "text.bubble.fill" : "text.bubble")
                }
            }
        }
    }

    private var completionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 56))
                .foregroundStyle(Color(hexToken: tokens.primary))
            Text("azkar.session_complete")
                .font(.title3.weight(.semibold))
            Text("azkar.session_complete_subtitle")
                .font(.subheadline)
                .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
