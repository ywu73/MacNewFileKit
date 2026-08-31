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
}

private func withIsolatedRepository<T>(
    _ body: (PreferenceRepository) throws -> T
) rethrows -> T {
    let suiteName = "MacNewFileKitTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    return try body(PreferenceRepository(defaults: defaults))
}
