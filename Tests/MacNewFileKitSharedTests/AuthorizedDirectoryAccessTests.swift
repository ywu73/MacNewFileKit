import Foundation
import Testing
@testable import MacNewFileKitShared

@Suite("AuthorizedDirectoryAccess")
struct AuthorizedDirectoryAccessTests {
    @Test("matches a directory and its descendants without prefix confusion")
    func matchesDescendants() {
        let resolver = AuthorizedDirectoryResolver()
        let root = URL(fileURLWithPath: "/tmp/work", isDirectory: true)

        #expect(resolver.contains(root, within: root))
        #expect(resolver.contains(root.appendingPathComponent("notes/file.md"), within: root))
        #expect(!resolver.contains(URL(fileURLWithPath: "/tmp/work-copy/file.md"), within: root))
    }

    @Test("round trips bookmark records through isolated preferences")
    func roundTripsRecords() throws {
        let suiteName = "MacNewFileKitAuthorizedDirectoryTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let repository = AuthorizedDirectoryRepository(defaults: defaults)
        let bookmark = AuthorizedDirectoryBookmark(
            displayPath: "/tmp/work",
            bookmarkData: Data([1, 2, 3])
        )

        try repository.save([bookmark])
        #expect(repository.load() == [bookmark])
    }

    @Test("shares bookmark records through an atomic JSON file")
    func sharesRecordsThroughFile() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let storageURL = directoryURL.appendingPathComponent("authorized-directories.json")
        let writer = AuthorizedDirectoryRepository(storageURL: storageURL)
        let reader = AuthorizedDirectoryRepository(storageURL: storageURL)
        let bookmark = AuthorizedDirectoryBookmark(
            displayPath: "/tmp/work",
            bookmarkData: Data([4, 5, 6])
        )

        try writer.save([bookmark])
        #expect(reader.load() == [bookmark])
    }
}
