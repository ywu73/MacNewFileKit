import FileCreationCore
import Foundation
import Testing
@testable import RightClickShared

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
            let preferences = RightClickPreferences(
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
}

private func withIsolatedRepository<T>(
    _ body: (PreferenceRepository) throws -> T
) rethrows -> T {
    let suiteName = "RightClickTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    return try body(PreferenceRepository(defaults: defaults))
}
