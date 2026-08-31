import Foundation
import Testing
@testable import FileCreationCore

@Suite("FinderTargetResolver")
struct FinderTargetResolverTests {
    private let resolver = FinderTargetResolver()
    private let directoryURL = URL(fileURLWithPath: "/tmp/folder", isDirectory: true)
    private let fileURL = URL(fileURLWithPath: "/tmp/folder/item.txt")

    @Test("uses a single selected folder as the destination")
    func selectedFolder() {
        let result = resolver.resolve(
            selectedURLs: [directoryURL],
            targetedURL: fileURL,
            isDirectory: { $0 == self.directoryURL }
        )
        #expect(result == directoryURL)
    }

    @Test("uses the parent when a single file is selected")
    func selectedFile() {
        let result = resolver.resolve(
            selectedURLs: [fileURL],
            targetedURL: fileURL,
            isDirectory: { _ in false }
        )
        #expect(result == directoryURL)
    }

    @Test("uses the containing folder for multiple selected items")
    func multipleSelection() {
        let secondURL = directoryURL.appendingPathComponent("second.txt")
        let result = resolver.resolve(
            selectedURLs: [fileURL, secondURL],
            targetedURL: directoryURL,
            isDirectory: { $0 == self.directoryURL }
        )
        #expect(result == directoryURL)
    }

    @Test("uses a targeted container for a background menu")
    func targetedContainer() {
        let result = resolver.resolve(
            selectedURLs: [],
            targetedURL: directoryURL,
            isDirectory: { $0 == self.directoryURL }
        )
        #expect(result == directoryURL)
    }

    @Test("returns nil when Finder has no target")
    func missingTarget() {
        let result = resolver.resolve(
            selectedURLs: [],
            targetedURL: nil,
            isDirectory: { _ in false }
        )
        #expect(result == nil)
    }
}
