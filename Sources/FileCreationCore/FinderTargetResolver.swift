import Foundation

public struct FinderTargetResolver: Sendable {
    public init() {}

    public func resolve(
        selectedURLs: [URL],
        targetedURL: URL?,
        isDirectory: (URL) -> Bool
    ) -> URL? {
        if selectedURLs.count == 1, let selectedURL = selectedURLs.first {
            return isDirectory(selectedURL)
                ? selectedURL
                : selectedURL.deletingLastPathComponent()
        }

        if let firstSelectedURL = selectedURLs.first {
            let sharedParent = firstSelectedURL.deletingLastPathComponent().standardizedFileURL
            guard selectedURLs.dropFirst().allSatisfy({
                $0.deletingLastPathComponent().standardizedFileURL == sharedParent
            }) else {
                return nil
            }
            return sharedParent
        }

        guard let targetedURL else { return nil }
        return isDirectory(targetedURL)
            ? targetedURL
            : targetedURL.deletingLastPathComponent()
    }
}
