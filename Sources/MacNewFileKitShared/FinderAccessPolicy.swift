import Foundation

public struct FinderAccessPolicy: Sendable {
    public let mode: FinderAccessMode

    public init(mode: FinderAccessMode) {
        self.mode = mode
    }

    public func monitoringURLs(
        authorizedDirectoryURLs: Set<URL>,
        mountedVolumeURLs: [URL]
    ) -> Set<URL> {
        switch mode {
        case .authorizedDirectories:
            return authorizedDirectoryURLs
        case .allLocalVolumes:
            var urls = Set([URL(fileURLWithPath: "/", isDirectory: true)])
            urls.formUnion(mountedVolumeURLs)
            return urls
        }
    }

    public func permitsTarget(isWithinAuthorizedDirectory: Bool) -> Bool {
        switch mode {
        case .authorizedDirectories:
            return isWithinAuthorizedDirectory
        case .allLocalVolumes:
            return true
        }
    }
}
