import ContentKit
import SwiftUI

/// Guided creation (docs/features/awrad.md screen 2): templates first,
/// custom wird as an explicit secondary path — steers users toward
/// maintained content rather than defaulting to custom.
struct AwradCreateSheet: View {
    @State var viewModel: AwradViewModel
    let locale: String
    @Environment(\.dismiss) private var dismiss
    @State private var showCustomForm = false

    @State private var customName = ""
    @State private var customTarget = "10"
    @State private var customUnit = "times"

    var body: some View {
        NavigationStack {
            List {
                Section("awrad.templates_section") {
                    ForEach(viewModel.templates) { template in
                        Button {
                            viewModel.createWird(fromTemplate: template)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading) {
                                Text(template.name)
                                Text(template.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Section {
                    if showCustomForm {
                        TextField("awrad.custom_name_placeholder", text: $customName)
                        TextField("awrad.custom_target_placeholder", text: $customTarget)
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif
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
                        .disabled(customName.isEmpty)
                    } else {
                        Button("awrad.create_custom") { showCustomForm = true }
                    }
                }
            }
            .navigationTitle(Text("awrad.create_title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
            }
        }
        .task { await viewModel.loadTemplates(locale: locale) }
    }
}
