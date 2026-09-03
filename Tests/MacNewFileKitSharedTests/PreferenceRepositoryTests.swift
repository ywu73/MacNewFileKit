import FileCreationCore
import Foundation
import Testing
@testable import MacNewFileKitShared

@Suite("PreferenceRepository")
struct PreferenceRepositoryTests {
    @Test("returns defaults when no preferences are saved")
    func returnsDefaults() {
        withIsolatedRepository { repository in
            #expect(repository.load() == .default)
        }
    }

    @Test("round trips built-in and custom templates")
    func roundTripsPreferences() throws {
        try withIsolatedRepository { repository in
            let preferences = MacNewFileKitPreferences(
                defaultBaseName: "new file",
                enabledTemplates: [.text, .markdown],
                customTemplates: [
                    CustomFileTemplate(
                        displayName: "YAML",
                        fileExtension: "yaml",
                        initialText: "---\n"
                    ),
                ]
            )

            try repository.save(preferences)
            #expect(repository.load() == preferences)
        }
    }

    @Test("loads preferences saved before the product rename")
    func loadsLegacyPreferences() throws {
        let suiteName = "MacNewFileKitLegacyTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let preferences = MacNewFileKitPreferences(
            defaultBaseName: "draft",
            enabledTemplates: [.markdown]
        )
        defaults.set(
            try JSONEncoder().encode(preferences),
            forKey: "rightClick.preferences.v1"
        )

        let repository = PreferenceRepository(defaults: defaults)
        #expect(repository.load() == preferences)
    }

    @Test("shares preferences through an atomic JSON file")
    func sharesPreferencesThroughFile() throws {
        try withTemporaryDirectory { directoryURL in
            let storageURL = directoryURL.appendingPathComponent("preferences.json")
            let writer = PreferenceRepository(storageURL: storageURL)
            let reader = PreferenceRepository(storageURL: storageURL)
            let preferences = MacNewFileKitPreferences(
                defaultBaseName: "draft",
                enabledTemplates: [.markdown]
            )

            try writer.save(preferences)
            #expect(reader.load() == preferences)
        }
    }

    @Test("enables newly added Office templates when migrating version 1 preferences")
    func migratesVersionOnePreferences() throws {
        let suiteName = "MacNewFileKitMigrationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let legacyPreferences = VersionOnePreferences(
            defaultBaseName: "draft",
            enabledTemplates: [.markdown],
            customTemplates: []
        )
        defaults.set(
            try JSONEncoder().encode(legacyPreferences),
            forKey: "macNewFileKit.preferences.v1"
        )

        let repository = PreferenceRepository(defaults: defaults)
        var migrated = repository.load()
        #expect(migrated.schemaVersion == MacNewFileKitPreferences.currentSchemaVersion)
        #expect(migrated.enabledTemplates == [.markdown, .word, .excel, .powerPoint])

        migrated.enabledTemplates.remove(.word)
        try repository.save(migrated)
        #expect(!repository.load().enabledTemplates.contains(.word))
    }
}

private struct VersionOnePreferences: Encodable {
    let defaultBaseName: String
    let enabledTemplates: Set<FileTemplate>
    let customTemplates: [CustomFileTemplate]
}

private func withIsolatedRepository<T>(
    _ body: (PreferenceRepository) throws -> T
) rethrows -> T {
    let suiteName = "MacNewFileKitTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    return try body(PreferenceRepository(defaults: defaults))
}

private func withTemporaryDirectory<T>(_ body: (URL) throws -> T) throws -> T {
    let directoryURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(
        at: directoryURL,
        withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(at: directoryURL) }
    return try body(directoryURL)
}
