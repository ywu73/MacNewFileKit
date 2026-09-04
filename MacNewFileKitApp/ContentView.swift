import FileCreationCore
import MacNewFileKitShared
import SwiftUI

struct ContentView: View {
    @ObservedObject var model: SettingsModel

    @State private var editorSession: TemplateEditorSession?

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

            if model.finderAccessMode == .allLocalVolumes {
                Section("Finder Access") {
                    Text(
                        "Global access is enabled for this local build. "
                            + "New File is available in writable Finder folders "
                            + "on the startup disk and mounted volumes."
                    )
                        .foregroundStyle(.secondary)
                }
            } else {
                Section("Authorized Folders") {
                    if model.authorizedDirectories.isEmpty {
                        Text("Choose at least one folder before using the Finder menu.")
                            .foregroundStyle(.secondary)
                    }

                    ForEach(model.authorizedDirectories) { bookmark in
                        HStack {
                            Text(bookmark.displayPath)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Button(role: .destructive) {
                                model.removeAuthorizedDirectory(id: bookmark.id)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .help("Remove Folder")
                        }
                    }

                    Button("Allow Folder…") {
                        model.authorizeDirectory()
                    }
                }
            }

            Section("New File") {
                TextField(
                    "Default base name",
                    text: Binding(
                        get: { model.defaultBaseNameDraft },
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
                ForEach(Array(model.preferences.customTemplates.enumerated()), id: \.element.id) {
                    index, template in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(template.displayName)
                            Text(".\(template.fileExtension)")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            editorSession = TemplateEditorSession(template: template)
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(.borderless)
                        .help("Edit Template")

                        Button {
                            model.duplicateCustomTemplate(id: template.id)
                        } label: {
                            Image(systemName: "plus.square.on.square")
                        }
                        .buttonStyle(.borderless)
                        .help("Duplicate Template")

                        Button {
                            model.moveCustomTemplate(id: template.id, offset: -1)
                        } label: {
                            Image(systemName: "arrow.up")
                        }
                        .buttonStyle(.borderless)
                        .disabled(index == 0)
                        .help("Move Up")

                        Button {
                            model.moveCustomTemplate(id: template.id, offset: 1)
                        } label: {
                            Image(systemName: "arrow.down")
                        }
                        .buttonStyle(.borderless)
                        .disabled(index == model.preferences.customTemplates.count - 1)
                        .help("Move Down")

                        Button(role: .destructive) {
                            model.removeCustomTemplate(id: template.id)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .help("Delete Template")
                    }
                }

                Button("Add Template…") {
                    editorSession = TemplateEditorSession()
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
        .sheet(item: $editorSession) { session in
            CustomTemplateEditorView(session: session) {
                model.saveCustomTemplate(
                    id: session.templateID,
                    displayName: $0,
                    fileExtension: $1,
                    initialText: $2
                )
            }
        }
    }

    private func localizedTemplateName(_ template: FileTemplate) -> String {
        NSLocalizedString(template.displayName, comment: "Built-in file template name")
    }
}

private struct TemplateEditorSession: Identifiable {
    let id = UUID()
    let templateID: UUID?
    let displayName: String
    let fileExtension: String
    let initialText: String

    init(template: CustomFileTemplate? = nil) {
        templateID = template?.id
        displayName = template?.displayName ?? ""
        fileExtension = template?.fileExtension ?? ""
        initialText = template?.initialText ?? ""
    }
}

private struct CustomTemplateEditorView: View {
    let session: TemplateEditorSession
    let onSave: (String, String, String) -> String?

    @Environment(\.dismiss) private var dismiss
    @State private var displayName: String
    @State private var fileExtension: String
    @State private var initialText: String
    @State private var validationError: String?

    init(
        session: TemplateEditorSession,
        onSave: @escaping (String, String, String) -> String?
    ) {
        self.session = session
        self.onSave = onSave
        _displayName = State(initialValue: session.displayName)
        _fileExtension = State(initialValue: session.fileExtension)
        _initialText = State(initialValue: session.initialText)
        _validationError = State(initialValue: nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(session.templateID == nil ? "Add Template" : "Edit Template")
                .font(.title2.bold())

            Form {
                TextField("Name", text: $displayName)
                TextField("Extension", text: $fileExtension)
                LabeledContent("Initial Content") {
                    TextEditor(text: $initialText)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 220)
                        .border(.separator)
                }
            }
            .formStyle(.grouped)

            if let validationError {
                Text(validationError)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                Button("Save") {
                    if let error = onSave(displayName, fileExtension, initialText) {
                        validationError = error
                    } else {
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 620, height: 430)
    }
}
