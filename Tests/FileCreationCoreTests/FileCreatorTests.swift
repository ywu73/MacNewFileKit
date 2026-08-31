import Foundation
import Testing
@testable import FileCreationCore

@Suite("FileCreator")
struct FileCreatorTests {
    @Test("creates an empty text document")
    func createsEmptyTextDocument() throws {
        try withTemporaryDirectory { directoryURL in
            let creator = FileCreator()
            let created = try creator.create(
                creator.request(for: .text, in: directoryURL)
            )

            #expect(created.url.lastPathComponent == "untitled.txt")
            #expect(created.collisionIndex == 1)
            #expect(FileManager.default.fileExists(atPath: created.url.path))
            #expect(try Data(contentsOf: created.url).isEmpty)
        }
    }

    @Test("uses a numbered name without overwriting an existing file")
    func avoidsOverwritingExistingFile() throws {
        try withTemporaryDirectory { directoryURL in
            let existingURL = directoryURL.appendingPathComponent("untitled.txt")
            try Data("keep me".utf8).write(to: existingURL)

            let creator = FileCreator()
            let created = try creator.create(
                creator.request(for: .text, in: directoryURL)
            )

            #expect(created.url.lastPathComponent == "untitled 2.txt")
            #expect(created.collisionIndex == 2)
            #expect(try String(contentsOf: existingURL, encoding: .utf8) == "keep me")
        }
    }

    @Test("writes the JSON template")
    func writesJSONTemplate() throws {
        try withTemporaryDirectory { directoryURL in
            let creator = FileCreator()
            let created = try creator.create(
                creator.request(for: .json, in: directoryURL)
            )

            #expect(created.url.lastPathComponent == "untitled.json")
            #expect(try String(contentsOf: created.url, encoding: .utf8) == "{}\n")
        }
    }

    @Test("normalizes a leading extension dot")
    func normalizesLeadingExtensionDot() throws {
        try withTemporaryDirectory { directoryURL in
            let created = try FileCreator().create(
                FileCreationRequest(
                    directoryURL: directoryURL,
                    baseName: "notes",
                    fileExtension: ".md"
                )
            )

            #expect(created.url.lastPathComponent == "notes.md")
        }
    }

    @Test("rejects unsafe names", arguments: ["", ".", "..", "a/b", "a:b"])
    func rejectsUnsafeBaseNames(_ baseName: String) throws {
        _ = try withTemporaryDirectory { directoryURL in
            #expect(throws: FileCreationError.self) {
                try FileCreator().create(
                    FileCreationRequest(
                        directoryURL: directoryURL,
                        baseName: baseName,
                        fileExtension: "txt"
                    )
                )
            }
        }
    }

    @Test("rejects unsafe extensions", arguments: ["", ".", "tar.gz", "a/b", "a:b"])
    func rejectsUnsafeExtensions(_ fileExtension: String) throws {
        _ = try withTemporaryDirectory { directoryURL in
            #expect(throws: FileCreationError.self) {
                try FileCreator().create(
                    FileCreationRequest(
                        directoryURL: directoryURL,
                        fileExtension: fileExtension
                    )
                )
            }
        }
    }

    @Test("rejects a missing target directory")
    func rejectsMissingDirectory() throws {
        try withTemporaryDirectory { directoryURL in
            let missingURL = directoryURL.appendingPathComponent("missing", isDirectory: true)
            #expect(throws: FileCreationError.invalidDirectory(missingURL)) {
                try FileCreator().create(
                    FileCreationRequest(
                        directoryURL: missingURL,
                        fileExtension: "txt"
                    )
                )
            }
        }
    }

    @Test("fails safely when collision attempts are disabled")
    func failsWhenCollisionAttemptsAreDisabled() throws {
        _ = try withTemporaryDirectory { directoryURL in
            #expect(throws: FileCreationError.tooManyNameCollisions(directoryURL)) {
                try FileCreator(maximumCollisionAttempts: 0).create(
                    FileCreationRequest(
                        directoryURL: directoryURL,
                        fileExtension: "txt"
                    )
                )
            }
        }
    }

    @Test("concurrent creation produces unique files")
    func concurrentCreationProducesUniqueFiles() async throws {
        try await withTemporaryDirectory { directoryURL in
            let creator = FileCreator()
            let request = creator.request(for: .text, in: directoryURL)

            let urls = try await withThrowingTaskGroup(of: URL.self) { group in
                for _ in 0..<24 {
                    group.addTask {
                        try creator.create(request).url
                    }
                }

                var urls: [URL] = []
                for try await url in group {
                    urls.append(url)
                }
                return urls
            }

            #expect(urls.count == 24)
            #expect(Set(urls).count == 24)
            #expect(urls.allSatisfy { FileManager.default.fileExists(atPath: $0.path) })
        }
    }
}

private func withTemporaryDirectory<T>(
    _ body: (URL) throws -> T
) throws -> T {
    let directoryURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(
        at: directoryURL,
        withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(at: directoryURL) }
    return try body(directoryURL)
}

private func withTemporaryDirectory<T>(
    _ body: (URL) async throws -> T
) async throws -> T {
    let directoryURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(
        at: directoryURL,
        withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(at: directoryURL) }
    return try await body(directoryURL)
}
