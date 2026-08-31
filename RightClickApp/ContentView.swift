import FileCreationCore
import SwiftUI

struct ContentView: View {
    @ObservedObject var model: SettingsModel

    @State private var customDisplayName = ""
    @State private var customExtension = ""

    var body: some View {
        Form {
            Section("Finder Extension") {
                LabeledContent("Status") {
                    Text(model.extensionEnabled ? "Enabled" : "Disabled")
                        .foregroundStyle(model.extensionEnabled ? .green : .secondary)
                }

                HStack {
                    Button("Manage Finder Extensions") {
                        model.showExtensionManagement()
                    }
                    Button("Refresh Status") {
                        model.refreshExtensionStatus()
                    }
                }
            }

            Section("New File") {
                TextField(
                    "Default base name",
                    text: Binding(
                        get: { model.preferences.defaultBaseName },
                        set: { value in
                            model.updateDefaultBaseName(value)
                        }
                    )
                )

                ForEach(FileTemplate.allCases) { template in
                    Toggle(
                        isOn: Binding(
                            get: { model.preferences.enabledTemplates.contains(template) },
                            set: { model.setEnabled($0, for: template) }
                        )
                    ) {
                        Text(
                            verbatim: "\(localizedTemplateName(template)) "
                                + "(.\(template.fileExtension))"
                        )
                    }
                }
            }

            Section("Custom Types") {
                ForEach(model.preferences.customTemplates) { template in
                    LabeledContent(template.displayName) {
                        Text(".\(template.fileExtension)")
                            .foregroundStyle(.secondary)
                    }
                }
                .onDelete { offsets in
                    model.removeCustomTemplates(at: offsets)
                }

                HStack {
                    TextField("Name", text: $customDisplayName)
                    TextField("Extension", text: $customExtension)
                        .frame(width: 120)
                    Button("Add") {
                        model.addCustomTemplate(
                            displayName: customDisplayName,
                            fileExtension: customExtension
                        )
                        customDisplayName = ""
                        customExtension = ""
                    }
                }
            }

            if let error = model.persistenceError {
                Section("Configuration Error") {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            model.refreshExtensionStatus()
        }
    }

    private func localizedTemplateName(_ template: FileTemplate) -> String {
        NSLocalizedString(template.displayName, comment: "Built-in file template name")
    }
}
