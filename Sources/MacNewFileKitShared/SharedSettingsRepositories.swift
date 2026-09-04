import Foundation

public struct SharedSettingsRepositories {
    public let preferences: PreferenceRepository
    public let authorizedDirectories: AuthorizedDirectoryRepository

    public init?(infoDictionary: [String: Any]) {
        if let domain = Self.nonEmptyString(
            infoDictionary["MacNewFileKitSharedPreferencesDomain"]
        ) {
            guard let defaults = UserDefaults(suiteName: domain) else { return nil }
            preferences = PreferenceRepository(defaults: defaults)
            authorizedDirectories = AuthorizedDirectoryRepository(defaults: defaults)
            return
        }

        guard let appGroupIdentifier = Self.nonEmptyString(
            infoDictionary["MacNewFileKitAppGroupIdentifier"]
        ), let preferences = PreferenceRepository(suiteName: appGroupIdentifier),
           let authorizedDirectories = AuthorizedDirectoryRepository(
               suiteName: appGroupIdentifier
           )
        else {
            return nil
        }

        self.preferences = preferences
        self.authorizedDirectories = authorizedDirectories
    }

    private static func nonEmptyString(_ value: Any?) -> String? {
        guard let value = value as? String, !value.isEmpty else { return nil }
        return value
    }
}
