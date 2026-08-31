import AppKit
import FileCreationCore
import FinderSync
import RightClickShared

@objc(FinderSync)
final class FinderSync: FIFinderSync {
    private static let customTemplateTagBase = 1_000

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
            item.tag = FileTemplate.allCases.firstIndex(of: template).map { $0 + 1 } ?? 0
            submenu.addItem(item)
        }

        if !preferences.customTemplates.isEmpty {
            submenu.addItem(.separator())
            for (index, customTemplate) in preferences.customTemplates.enumerated() {
                let item = NSMenuItem(
                    title: customTemplate.displayName,
                    action: #selector(createCustomFile(_:)),
                    keyEquivalent: ""
                )
                item.tag = Self.customTemplateTagBase + index
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
        guard let template = builtInTemplate(for: sender),
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
        let preferences = repository?.load() ?? .default
        guard let template = customTemplate(for: sender, in: preferences),
              let directoryURL = targetDirectoryURL()
        else {
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

    private func builtInTemplate(for item: NSMenuItem) -> FileTemplate? {
        let index = item.tag - 1
        if FileTemplate.allCases.indices.contains(index) {
            return FileTemplate.allCases[index]
        }

        return FileTemplate.allCases.first {
            localized($0.displayName) == item.title
        }
    }

    private func customTemplate(
        for item: NSMenuItem,
        in preferences: RightClickPreferences
    ) -> CustomFileTemplate? {
        let index = item.tag - Self.customTemplateTagBase
        if preferences.customTemplates.indices.contains(index) {
            return preferences.customTemplates[index]
        }

        return preferences.customTemplates.first {
            $0.displayName == item.title
        }
    }

    private func performCreation(_ request: FileCreationRequest) {
        do {
            let created = try creator.create(request)
            NSWorkspace.shared.activateFileViewerSelecting([created.url])
        } catch {
            NSLog("RightClick could not create file: %@", error.localizedDescription)
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
