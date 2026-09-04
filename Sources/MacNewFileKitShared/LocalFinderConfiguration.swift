import Foundation

public struct LocalFinderConfiguration: Sendable {
    public static let pathFallbackInfoKey = "MacNewFileKitLocalPathFallback"

    public let allowsPathFallback: Bool

    public init(infoDictionary: [String: Any]) {
        allowsPathFallback = infoDictionary[Self.pathFallbackInfoKey] as? Bool == true
    }
}
