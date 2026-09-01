import Foundation

public struct AuthorizedDirectoryBookmark: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var displayPath: String
    public var bookmarkData: Data

    public init(id: UUID = UUID(), displayPath: String, bookmarkData: Data) {
        self.id = id
        self.displayPath = displayPath
        self.bookmarkData = bookmarkData
    }
}

public enum AuthorizedDirectoryError: Error, Equatable, Sendable {
    case bookmarkCreationFailed(String)
    case bookmarkResolutionFailed(String)
}

extension AuthorizedDirectoryError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .bookmarkCreationFailed(path):
            "Could not save access to: \(path)"
        case let .bookmarkResolutionFailed(path):
            "Could not restore access to: \(path)"
        }
    }
}

public struct AuthorizedDirectoryResolver: Sendable {
    public init() {}

    public func makeBookmark(for directoryURL: URL) throws -> AuthorizedDirectoryBookmark {
        let normalizedURL = normalized(directoryURL)
        do {
            let data = try normalizedURL.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: [.isDirectoryKey],
                relativeTo: nil
            )
            return AuthorizedDirectoryBookmark(
                displayPath: normalizedURL.path,
                bookmarkData: data
            )
        } catch {
            throw AuthorizedDirectoryError.bookmarkCreationFailed(normalizedURL.path)
        }
    }

    public func resolve(
        _ bookmark: AuthorizedDirectoryBookmark
    ) throws -> (url: URL, isStale: Bool) {
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: bookmark.bookmarkData,
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            return (normalized(url), isStale)
        } catch {
            throw AuthorizedDirectoryError.bookmarkResolutionFailed(bookmark.displayPath)
        }
    }

    public func contains(_ candidateURL: URL, within rootURL: URL) -> Bool {
        let candidateComponents = normalized(candidateURL).pathComponents
        let rootComponents = normalized(rootURL).pathComponents
        guard candidateComponents.count >= rootComponents.count else { return false }
        return Array(candidateComponents.prefix(rootComponents.count)) == rootComponents
    }

    private func normalized(_ url: URL) -> URL {
        url.standardizedFileURL.resolvingSymlinksInPath()
    }
}

public final class AuthorizedDirectoryRepository: @unchecked Sendable {
    private static let storageKey = "macNewFileKit.authorizedDirectories.v1"
    private static let storageFilename = "authorized-directories.json"

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

    public func load() -> [AuthorizedDirectoryBookmark] {
        guard let data = loadData(),
              let bookmarks = try? decoder.decode([AuthorizedDirectoryBookmark].self, from: data)
        else {
            return []
        }
        return bookmarks
    }

    public func save(_ bookmarks: [AuthorizedDirectoryBookmark]) throws {
        try saveData(encoder.encode(bookmarks))
    }

    private func loadData() -> Data? {
        switch storage {
        case let .appGroupFile(url, legacyDefaults):
            if let data = try? Data(contentsOf: url) {
                return data
            }
            guard let legacyData = legacyDefaults?.data(forKey: Self.storageKey) else {
                return nil
            }
            try? legacyData.write(to: url, options: .atomic)
            return legacyData
        case let .defaults(defaults):
            return defaults.data(forKey: Self.storageKey)
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
