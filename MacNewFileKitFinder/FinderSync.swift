import AppKit
import FileCreationCore
import FinderSync
import MacNewFileKitShared

@objc(FinderSync)
final class FinderSync: FIFinderSync {
    private static let customTemplateTagBase = 1_000

    private let controller = FIFinderSyncController.default()
    private let creator = FileCreator()
    private let targetResolver = FinderTargetResolver()
    private let repository: PreferenceRepository?
    private let authorizedDirectorySession: AuthorizedDirectorySession
    private var customTemplateIDsByTag: [Int: UUID] = [:]

    override init() {
        let suiteName = Bundle.main.object(
            forInfoDictionaryKey: "MacNewFileKitAppGroupIdentifier"
        ) as? String ?? "group.io.github.ywu73.MacNewFileKit"
        repository = PreferenceRepository(suiteName: suiteName)
        authorizedDirectorySession = AuthorizedDirectorySession(
            repository: AuthorizedDirectoryRepository(suiteName: suiteName),
            allowLocalPathFallback: Bundle.main.object(
                forInfoDictionaryKey: "MacNewFileKitLocalPathFallback"
            ) as? Bool == true
        )

        super.init()

        // Monitoring root exposes the menu throughout local Finder locations.
        // Actual availability and sandbox behavior must be verified on a signed build.
        controller.directoryURLs = [URL(fileURLWithPath: "/", isDirectory: true)]
        authorizedDirectorySession.refresh()
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        guard menuKind == .contextualMenuForItems
                || menuKind == .contextualMenuForContainer
                || menuKind == .contextualMenuForSidebar,
              let directoryURL = targetDirectoryURL()
        else {
            return nil
        }

        authorizedDirectorySession.refresh()
        let isAuthorized = authorizedDirectorySession.contains(directoryURL)
        #if DEBUG
        NSLog(
            "MacNewFileKit menu target=%@ authorized=%d roots=%@",
            directoryURL.path,
            isAuthorized,
            authorizedDirectorySession.rootPaths.joined(separator: ", ")
        )
        #endif
        guard isAuthorized else { return nil }

        let preferences = repository?.load() ?? .default
        let menu = NSMenu(title: "MacNewFileKit")
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

        customTemplateIDsByTag.removeAll(keepingCapacity: true)
        if !preferences.customTemplates.isEmpty {
            submenu.addItem(.separator())
            for (index, customTemplate) in preferences.customTemplates.enumerated() {
                let item = NSMenuItem(
                    title: customTemplate.displayName,
                    action: #selector(createCustomFile(_:)),
                    keyEquivalent: ""
                )
                item.tag = Self.customTemplateTagBase + index
                customTemplateIDsByTag[item.tag] = customTemplate.id
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
              let directoryURL = authorizedTargetDirectoryURL()
        else {
            return
        }

        let preferences = repository?.load() ?? .default
        do {
            performCreation(
                try creator.request(
                    for: template,
                    in: directoryURL,
                    baseName: preferences.defaultBaseName
                )
            )
        } catch {
            NSLog("MacNewFileKit could not load a built-in template: %@", error.localizedDescription)
            showCreationError(error)
        }
    }

    @objc
    private func createCustomFile(_ sender: NSMenuItem) {
        let preferences = repository?.load() ?? .default
        guard let template = customTemplate(for: sender, in: preferences),
              let directoryURL = authorizedTargetDirectoryURL()
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
        in preferences: MacNewFileKitPreferences
    ) -> CustomFileTemplate? {
        if let id = customTemplateIDsByTag[item.tag],
           let template = preferences.customTemplates.first(where: { $0.id == id }) {
            return template
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
            NSLog("MacNewFileKit could not create file: %@", error.localizedDescription)
            showCreationError(error)
        }
    }

    private func showCreationError(_ error: Error) {
        let messageText = localized("Could Not Create File")
        let informativeText = localizedDescription(for: error)

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

    private func authorizedTargetDirectoryURL() -> URL? {
        guard let directoryURL = targetDirectoryURL() else { return nil }
        authorizedDirectorySession.refresh()
        let isAuthorized = authorizedDirectorySession.contains(directoryURL)
        #if DEBUG
        NSLog(
            "MacNewFileKit action target=%@ authorized=%d roots=%@",
            directoryURL.path,
            isAuthorized,
            authorizedDirectorySession.rootPaths.joined(separator: ", ")
        )
        #endif
        return isAuthorized ? directoryURL : nil
    }

    private func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, bundle: .main, comment: "")
    }

    private func localizedDescription(for error: Error) -> String {
        guard let error = error as? FileCreationError else {
            return error.localizedDescription
        }

        let key: String
        let argument: String
        switch error {
        case let .invalidDirectory(url):
            key = "The target is not a writable directory: %@"
            argument = url.path
        case let .invalidBaseName(name):
            key = "The base name is invalid: %@"
            argument = name
        case let .invalidFileExtension(fileExtension):
            key = "The file extension is invalid: %@"
            argument = fileExtension
        case let .missingTemplateResource(filename):
            key = "The built-in template is unavailable: %@"
            argument = filename
        case let .permissionDenied(url):
            key = "Permission was denied while creating a file in: %@"
            argument = url.path
        case let .readOnlyFileSystem(url):
            key = "The target file system is read-only: %@"
            argument = url.path
        case let .tooManyNameCollisions(url):
            key = "No available file name could be found in: %@"
            argument = url.path
        case let .systemError(path, code):
            let format = localized("The system could not create %@ (errno %d).")
            return String(format: format, path, code)
        }
        return String(format: localized(key), argument)
    }
}

private final class AuthorizedDirectorySession {
    private struct Access {
        let url: URL
        let didStartSecurityScope: Bool
    }

    private let repository: AuthorizedDirectoryRepository?
    private let resolver = AuthorizedDirectoryResolver()
    private let allowLocalPathFallback: Bool
    private var loadedBookmarks: [AuthorizedDirectoryBookmark] = []
    private var activeAccess: [UUID: Access] = [:]

    init(
        repository: AuthorizedDirectoryRepository?,
        allowLocalPathFallback: Bool = false
    ) {
        self.repository = repository
        self.allowLocalPathFallback = allowLocalPathFallback
    }

    var rootPaths: [String] {
        activeAccess.values.map(\.url.path).sorted()
    }

    deinit {
        stopAccessingDirectories()
    }

    func refresh() {
        let bookmarks = repository?.load() ?? []
        guard bookmarks != loadedBookmarks else { return }

        stopAccessingDirectories()
        loadedBookmarks = bookmarks

        for bookmark in bookmarks {
            do {
                let result = try resolver.resolve(bookmark)
                let didStart = result.url.startAccessingSecurityScopedResource()
                activeAccess[bookmark.id] = Access(
                    url: result.url,
                    didStartSecurityScope: didStart
                )

                if result.isStale,
                   let refreshed = try? resolver.makeBookmark(for: result.url) {
                    refreshStoredBookmark(refreshed, preservingID: bookmark.id)
                }
            } catch {
                if allowLocalPathFallback,
                   activateLocalPathFallback(for: bookmark) {
                    NSLog(
                        "MacNewFileKit using local path fallback for %@",
                        bookmark.displayPath
                    )
                    continue
                }
                NSLog(
                    "MacNewFileKit could not restore folder access for %@: %@",
                    bookmark.displayPath,
                    error.localizedDescription
                )
            }
        }
    }

    private func activateLocalPathFallback(
        for bookmark: AuthorizedDirectoryBookmark
    ) -> Bool {
        let url = URL(fileURLWithPath: bookmark.displayPath, isDirectory: true)
            .standardizedFileURL
            .resolvingSymlinksInPath()
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue
        else {
            return false
        }

        activeAccess[bookmark.id] = Access(url: url, didStartSecurityScope: false)
        return true
    }

    func contains(_ directoryURL: URL) -> Bool {
        activeAccess.values.contains {
            resolver.contains(directoryURL, within: $0.url)
        }
    }

    private func stopAccessingDirectories() {
        for access in activeAccess.values where access.didStartSecurityScope {
            access.url.stopAccessingSecurityScopedResource()
        }
        activeAccess.removeAll(keepingCapacity: true)
    }

    private func refreshStoredBookmark(
        _ bookmark: AuthorizedDirectoryBookmark,
        preservingID id: UUID
    ) {
        guard let repository else { return }
        let replacement = AuthorizedDirectoryBookmark(
            id: id,
            displayPath: bookmark.displayPath,
            bookmarkData: bookmark.bookmarkData
        )
        loadedBookmarks = loadedBookmarks.map { $0.id == id ? replacement : $0 }
        try? repository.save(loadedBookmarks)
    }
}
