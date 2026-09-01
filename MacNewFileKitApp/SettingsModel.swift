import AppKit
import Combine
import FileCreationCore
import FinderSync
import Foundation
import MacNewFileKitShared

@MainActor
final class SettingsModel: ObservableObject {
    @Published var preferences: MacNewFileKitPreferences
    @Published var defaultBaseNameDraft: String
    @Published private(set) var extensionEnabled = false
    @Published private(set) var authorizedDirectories: [AuthorizedDirectoryBookmark]
    @Published private(set) var persistenceError: String?

    private let repository: PreferenceRepository?
    private let authorizedDirectoryRepository: AuthorizedDirectoryRepository?
    private let authorizedDirectoryResolver = AuthorizedDirectoryResolver()

    init() {
        let suiteName = Bundle.main.object(
            forInfoDictionaryKey: "MacNewFileKitAppGroupIdentifier"
        ) as? String ?? "group.io.github.ywu73.MacNewFileKit"
        let repository = PreferenceRepository(suiteName: suiteName)
        let authorizedDirectoryRepository = AuthorizedDirectoryRepository(suiteName: suiteName)
        let preferences = repository?.load() ?? .default
        self.repository = repository
        self.preferences = preferences
        self.defaultBaseNameDraft = preferences.defaultBaseName
        self.authorizedDirectoryRepository = authorizedDirectoryRepository
        self.authorizedDirectories = authorizedDirectoryRepository?.load() ?? []
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
        defaultBaseNameDraft = value
        do {
            preferences.defaultBaseName = try FileNamePolicy.normalizedBaseName(value)
            try persistPreferences()
            persistenceError = nil
        } catch {
            persistenceError = localizedDescription(for: error)
        }
    }

    func saveCustomTemplate(
        id: UUID?,
        displayName: String,
        fileExtension: String,
        initialText: String
    ) -> String? {
        do {
            var catalog = CustomTemplateCatalog(templates: preferences.customTemplates)
            if let id {
                try catalog.update(
                    id: id,
                    displayName: displayName,
                    fileExtension: fileExtension,
                    initialText: initialText
                )
            } else {
                try catalog.add(
                    displayName: displayName,
                    fileExtension: fileExtension,
                    initialText: initialText
                )
            }
            preferences.customTemplates = catalog.templates
            try persistPreferences()
            persistenceError = nil
            return nil
        } catch {
            persistenceError = localizedDescription(for: error)
            return persistenceError
        }
    }

    func duplicateCustomTemplate(id: UUID) {
        updateCatalog { catalog in
            try catalog.duplicate(id: id)
        }
    }

    func removeCustomTemplate(id: UUID) {
        updateCatalog { catalog in
            try catalog.remove(id: id)
        }
    }

    func moveCustomTemplate(id: UUID, offset: Int) {
        updateCatalog { catalog in
            try catalog.move(id: id, offset: offset)
        }
    }

    func authorizeDirectory() {
        let panel = NSOpenPanel()
        panel.title = NSLocalizedString(
            "Choose a folder where MacNewFileKit may create files.",
            comment: "Authorized directory picker title"
        )
        panel.prompt = NSLocalizedString("Allow Folder", comment: "Folder authorization button")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            var bookmark = try authorizedDirectoryResolver.makeBookmark(for: url)
            var bookmarks = authorizedDirectories.filter { $0.displayPath != bookmark.displayPath }
            if let existing = authorizedDirectories.first(where: {
                $0.displayPath == bookmark.displayPath
            }) {
                bookmark = AuthorizedDirectoryBookmark(
                    id: existing.id,
                    displayPath: bookmark.displayPath,
                    bookmarkData: bookmark.bookmarkData
                )
            }
            bookmarks.append(bookmark)
            try authorizedDirectoryRepository?.save(bookmarks)
            authorizedDirectories = bookmarks
            persistenceError = nil
        } catch {
            persistenceError = localizedDescription(for: error)
        }
    }

    func removeAuthorizedDirectory(id: UUID) {
        do {
            let bookmarks = authorizedDirectories.filter { $0.id != id }
            try authorizedDirectoryRepository?.save(bookmarks)
            authorizedDirectories = bookmarks
            persistenceError = nil
        } catch {
            persistenceError = localizedDescription(for: error)
        }
    }

    func refreshExtensionStatus() {
        extensionEnabled = FIFinderSyncController.isExtensionEnabled
    }

    func showExtensionManagement() {
        FIFinderSyncController.showExtensionManagementInterface()
    }

    private func updateCatalog(
        _ operation: (inout CustomTemplateCatalog) throws -> Void
    ) {
        do {
            var catalog = CustomTemplateCatalog(templates: preferences.customTemplates)
            try operation(&catalog)
            preferences.customTemplates = catalog.templates
            try persistPreferences()
            persistenceError = nil
        } catch {
            persistenceError = localizedDescription(for: error)
        }
    }

    private func persist() {
        do {
            try persistPreferences()
            persistenceError = nil
        } catch {
            persistenceError = localizedDescription(for: error)
        }
    }

    private func persistPreferences() throws {
        guard let repository else {
            throw SettingsError.sharedAppGroupUnavailable
        }
        try repository.save(preferences)
    }

    private func localizedDescription(for error: Error) -> String {
        switch error {
        case CustomTemplateCatalogError.emptyDisplayName:
            return NSLocalizedString(
                "The custom template name cannot be empty.",
                comment: "Custom template validation error"
            )
        case let CustomTemplateCatalogError.duplicateDisplayName(name):
            return String(
                format: NSLocalizedString(
                    "A custom template named \"%@\" already exists.",
                    comment: "Duplicate custom template error"
                ),
                name
            )
        case CustomTemplateCatalogError.missingTemplate:
            return NSLocalizedString(
                "The custom template no longer exists.",
                comment: "Missing custom template error"
            )
        case let FileCreationError.invalidBaseName(name):
            return String(
                format: NSLocalizedString(
                    "The base name is invalid: %@",
                    comment: "Invalid base name error"
                ),
                name
            )
        case let FileCreationError.invalidFileExtension(fileExtension):
            return String(
                format: NSLocalizedString(
                    "The file extension is invalid: %@",
                    comment: "Invalid extension error"
                ),
                fileExtension
            )
        case let AuthorizedDirectoryError.bookmarkCreationFailed(path):
            return String(
                format: NSLocalizedString(
                    "Could not save access to: %@",
                    comment: "Folder bookmark creation error"
                ),
                path
            )
        case let AuthorizedDirectoryError.bookmarkResolutionFailed(path):
            return String(
                format: NSLocalizedString(
                    "Could not restore access to: %@",
                    comment: "Folder bookmark resolution error"
                ),
                path
            )
        default:
            let key = error.localizedDescription
            let localized = NSLocalizedString(key, comment: "Configuration error")
            return localized == key ? key : localized
        }
    }

    private enum SettingsError: LocalizedError {
        case sharedAppGroupUnavailable

        var errorDescription: String? {
            switch self {
            case .sharedAppGroupUnavailable:
                "The shared App Group is unavailable."
            }
        }
    }
}
