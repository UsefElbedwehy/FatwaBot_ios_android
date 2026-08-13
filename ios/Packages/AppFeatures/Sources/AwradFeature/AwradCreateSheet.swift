import ContentKit
import DesignSystemKit
import SwiftUI

/// Guided creation (docs/features/awrad.md screen 2): templates first,
/// custom wird as an explicit secondary path — steers users toward
/// maintained content rather than defaulting to custom.
struct AwradCreateSheet: View {
    @State var viewModel: AwradViewModel
    let locale: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var showCustomForm = false

    @State private var customName = ""
    @State private var customTarget = "10"
    @State private var customUnit = "times"

    private var tokens: ColorTokens {
        colorScheme == .dark ? DesignTokens.bundledDefault.dark : DesignTokens.bundledDefault.light
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 12) {
                        BrandSectionHeader("awrad.templates_section", systemImage: "square.stack.3d.up.fill", tokens: tokens)
                        VStack(spacing: 12) {
                            ForEach(viewModel.templates) { template in
                                templateCard(template)
                            }
                        }
                    }

                    customSection
                }
                .padding(20)
            }
            .brandScreenBackground(tokens)
            .navigationTitle(Text("awrad.create_title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
            }
        }
        .task { await viewModel.loadTemplates(locale: locale) }
    }

    // MARK: - Template card

    private func templateCard(_ template: WirdTemplate) -> some View {
        Button {
            viewModel.createWird(fromTemplate: template)
            dismiss()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color(hexToken: tokens.primaryContainer))
                    Image(systemName: "leaf.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(hexToken: tokens.primary))
                }
                .frame(width: 40, height: 40)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(template.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color(hexToken: tokens.onSurface))
                    Text(template.description)
                        .font(.caption)
                        .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                }
                Spacer(minLength: 8)
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color(hexToken: tokens.primary))
            }
            .brandCard(tokens)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Custom section

    @ViewBuilder
    private var customSection: some View {
        if showCustomForm {
            VStack(alignment: .leading, spacing: 14) {
                brandField("awrad.custom_name_placeholder", text: $customName)
                brandField("awrad.custom_target_placeholder", text: $customTarget, numeric: true)

                Button("awrad.save_custom") {
                    viewModel.createCustomWird(
                        name: customName.isEmpty ? "ورد مخصص" : customName,
                        type: "custom",
                        target: Int(customTarget) ?? 1,
                        unit: customUnit,
                        frequency: "daily"
                    )
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
                .opacity(customName.isEmpty ? 0.5 : 1)
                .disabled(customName.isEmpty)
            }
            .brandCard(tokens)
        } else {
            Button("awrad.create_custom") { showCustomForm = true }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(hexToken: tokens.primary))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(hexToken: tokens.surfaceElevated), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            Color(hexToken: tokens.primary).opacity(0.4),
                            style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                        )
                )
        }
    }

    private func brandField(_ placeholder: LocalizedStringKey, text: Binding<String>, numeric: Bool = false) -> some View {
        let field = TextField(placeholder, text: text)
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
        return field.keyboardType(numeric ? .numberPad : .default)
        #else
        return field
        #endif
    }
}
