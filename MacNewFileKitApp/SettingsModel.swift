import Combine
import FileCreationCore
import FinderSync
import Foundation
import MacNewFileKitShared

@MainActor
final class SettingsModel: ObservableObject {
    @Published var preferences: MacNewFileKitPreferences
    @Published private(set) var extensionEnabled = false
    @Published private(set) var persistenceError: String?

    private let repository: PreferenceRepository?

    init() {
        let suiteName = Bundle.main.object(
            forInfoDictionaryKey: "MacNewFileKitAppGroupIdentifier"
        ) as? String ?? "group.io.github.ywu73.MacNewFileKit"
        let repository = PreferenceRepository(suiteName: suiteName)
        self.repository = repository
        self.preferences = repository?.load() ?? .default
        refreshExtensionStatus()
    }

    func setEnabled(_ enabled: Bool, for template: FileTemplate) {
        if enabled {
            preferences.enabledTemplates.insert(template)
        } else {
            preferences.enabledTemplates.remove(template)
        }
        persist()
    }

    func updateDefaultBaseName(_ value: String) {
        preferences.defaultBaseName = value
        persist()
    }

    func addCustomTemplate(displayName: String, fileExtension: String) {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            persistenceError = NSLocalizedString(
                "The custom type name cannot be empty.",
                comment: "Custom template validation error"
            )
            return
        }

        let suffix: String
        do {
            suffix = try FileNamePolicy.normalizedFileExtension(fileExtension)
        } catch {
            persistenceError = error.localizedDescription
            return
        }

        preferences.customTemplates.append(
            CustomFileTemplate(displayName: name, fileExtension: suffix)
        )
        persist()
    }

    func removeCustomTemplates(at offsets: IndexSet) {
        preferences.customTemplates.remove(atOffsets: offsets)
        persist()
    }

    func refreshExtensionStatus() {
        extensionEnabled = FIFinderSyncController.isExtensionEnabled
    }

    func showExtensionManagement() {
        FIFinderSyncController.showExtensionManagementInterface()
    }

    private func persist() {
        guard let repository else {
            persistenceError = "The shared App Group is unavailable."
            return
        }

        do {
            try repository.save(preferences)
            persistenceError = nil
        } catch {
            persistenceError = error.localizedDescription
        }
    }
}
