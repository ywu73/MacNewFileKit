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
    private static let storageFilename = "preferences.json"

    private enum Storage {
        case appGroupFile(URL, legacyDefaults: UserDefaults?)
        case defaults(UserDefaults)
    }

    private let storage: Storage
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init?(suiteName: String) {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: suiteName
        ), let defaults = UserDefaults(suiteName: suiteName) else {
            return nil
        }
        storage = .appGroupFile(
            containerURL.appendingPathComponent(Self.storageFilename, isDirectory: false),
            legacyDefaults: defaults
        )
    }

    public init(defaults: UserDefaults) {
        storage = .defaults(defaults)
    }

    init(storageURL: URL, legacyDefaults: UserDefaults? = nil) {
        storage = .appGroupFile(storageURL, legacyDefaults: legacyDefaults)
    }

    public func load() -> MacNewFileKitPreferences {
        guard let data = loadData(),
              let preferences = try? decoder.decode(MacNewFileKitPreferences.self, from: data)
        else {
            return .default
        }
        return preferences
    }

    public func save(_ preferences: MacNewFileKitPreferences) throws {
        try saveData(encoder.encode(preferences))
    }

    private func loadData() -> Data? {
        switch storage {
        case let .appGroupFile(url, legacyDefaults):
            if let data = try? Data(contentsOf: url) {
                return data
            }
            guard let legacyData = legacyDefaults?.data(forKey: Self.storageKey)
                    ?? legacyDefaults?.data(forKey: Self.legacyStorageKey)
            else {
                return nil
            }
            try? legacyData.write(to: url, options: .atomic)
            return legacyData
        case let .defaults(defaults):
            return defaults.data(forKey: Self.storageKey)
                ?? defaults.data(forKey: Self.legacyStorageKey)
        }
    }

    private func saveData(_ data: Data) throws {
        switch storage {
        case let .appGroupFile(url, _):
            try data.write(to: url, options: .atomic)
        case let .defaults(defaults):
            defaults.set(data, forKey: Self.storageKey)
        }
    }
}
