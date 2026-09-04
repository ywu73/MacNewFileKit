import Foundation

public enum FinderAccessMode: Sendable {
    case authorizedDirectories
    case allLocalVolumes
}

public struct LocalFinderConfiguration: Sendable {
    public static let globalAccessInfoKey = "MacNewFileKitLocalGlobalAccess"

    public let accessMode: FinderAccessMode

    public init(infoDictionary: [String: Any]) {
        accessMode = infoDictionary[Self.globalAccessInfoKey] as? Bool == true
            ? .allLocalVolumes
            : .authorizedDirectories
    }
}
