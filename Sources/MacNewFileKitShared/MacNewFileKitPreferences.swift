import FileCreationCore
import Foundation

public struct CustomFileTemplate: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var displayName: String
    public var fileExtension: String
    public var initialText: String

    public init(
        id: UUID = UUID(),
        displayName: String,
        fileExtension: String,
        initialText: String = ""
    ) {
        self.id = id
        self.displayName = displayName
        self.fileExtension = fileExtension
        self.initialText = initialText
    }
}

public struct MacNewFileKitPreferences: Codable, Equatable, Sendable {
    public var defaultBaseName: String
    public var enabledTemplates: Set<FileTemplate>
    public var customTemplates: [CustomFileTemplate]

    public init(
        defaultBaseName: String = "untitled",
        enabledTemplates: Set<FileTemplate> = Set(FileTemplate.allCases),
        customTemplates: [CustomFileTemplate] = []
    ) {
        self.defaultBaseName = defaultBaseName
        self.enabledTemplates = enabledTemplates
        self.customTemplates = customTemplates
    }

    public static let `default` = MacNewFileKitPreferences()
}

public final class PreferenceRepository: @unchecked Sendable {
    private static let storageKey = "macNewFileKit.preferences.v1"
    private static let legacyStorageKey = "rightClick.preferences.v1"

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init?(suiteName: String) {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return nil
        }
        self.defaults = defaults
    }

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public func load() -> MacNewFileKitPreferences {
        guard let data = defaults.data(forKey: Self.storageKey)
                ?? defaults.data(forKey: Self.legacyStorageKey),
              let preferences = try? decoder.decode(MacNewFileKitPreferences.self, from: data)
        else {
            return .default
        }
        return preferences
    }

    public func save(_ preferences: MacNewFileKitPreferences) throws {
        defaults.set(try encoder.encode(preferences), forKey: Self.storageKey)
    }
}
