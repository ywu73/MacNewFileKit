import AppKit
import FileCreationCore
import FinderSync
import RightClickShared

@objc(FinderSync)
final class FinderSync: FIFinderSync {
    private let controller = FIFinderSyncController.default()
    private let creator = FileCreator()
    private let targetResolver = FinderTargetResolver()
    private let repository: PreferenceRepository?

    override init() {
        let suiteName = Bundle.main.object(
            forInfoDictionaryKey: "RightClickAppGroupIdentifier"
        ) as? String ?? "group.com.example.RightClick"
        repository = PreferenceRepository(suiteName: suiteName)

        super.init()

        // Monitoring root exposes the menu throughout local Finder locations.
        // Actual availability and sandbox behavior must be verified on a signed build.
        controller.directoryURLs = [URL(fileURLWithPath: "/", isDirectory: true)]
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        guard menuKind == .contextualMenuForItems
                || menuKind == .contextualMenuForContainer
                || menuKind == .contextualMenuForSidebar,
              targetDirectoryURL() != nil
        else {
            return nil
        }

        let preferences = repository?.load() ?? .default
        let menu = NSMenu(title: "RightClick")
        let newFileTitle = localized("New File")
        let newFileItem = NSMenuItem(title: newFileTitle, action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: newFileTitle)

        for template in FileTemplate.allCases where preferences.enabledTemplates.contains(template) {
            let item = NSMenuItem(
                title: localized(template.displayName),
                action: #selector(createBuiltInFile(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = template.rawValue
            submenu.addItem(item)
        }

        if !preferences.customTemplates.isEmpty {
            submenu.addItem(.separator())
            for customTemplate in preferences.customTemplates {
                let item = NSMenuItem(
                    title: customTemplate.displayName,
                    action: #selector(createCustomFile(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = customTemplate.id.uuidString
                submenu.addItem(item)
            }
        }

        guard !submenu.items.isEmpty else { return nil }
        newFileItem.submenu = submenu
        menu.addItem(newFileItem)
        return menu
    }

    @objc
    private func createBuiltInFile(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let template = FileTemplate(rawValue: rawValue),
              let directoryURL = targetDirectoryURL()
        else {
            return
        }

        let preferences = repository?.load() ?? .default
        performCreation(
            FileCreationRequest(
                directoryURL: directoryURL,
                baseName: preferences.defaultBaseName,
                fileExtension: template.fileExtension,
                contents: template.initialContents
            )
        )
    }

    @objc
    private func createCustomFile(_ sender: NSMenuItem) {
        guard let identifier = sender.representedObject as? String,
              let id = UUID(uuidString: identifier),
              let directoryURL = targetDirectoryURL()
        else {
            return
        }

        let preferences = repository?.load() ?? .default
        guard let template = preferences.customTemplates.first(where: { $0.id == id }) else {
            return
        }

        performCreation(
            FileCreationRequest(
                directoryURL: directoryURL,
                baseName: preferences.defaultBaseName,
                fileExtension: template.fileExtension,
                contents: Data(template.initialText.utf8)
            )
        )
    }

    private func performCreation(_ request: FileCreationRequest) {
        do {
            let created = try creator.create(request)
            NSWorkspace.shared.activateFileViewerSelecting([created.url])
        } catch {
            showCreationError(error)
        }
    }

    private func showCreationError(_ error: Error) {
        let messageText = localized("Could Not Create File")
        let informativeText = error.localizedDescription

        Task { @MainActor in
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = messageText
            alert.informativeText = informativeText
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    private func targetDirectoryURL() -> URL? {
        targetResolver.resolve(
            selectedURLs: controller.selectedItemURLs() ?? [],
            targetedURL: controller.targetedURL(),
            isDirectory: isDirectory
        )
    }

    private func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, bundle: .main, comment: "")
    }
}
