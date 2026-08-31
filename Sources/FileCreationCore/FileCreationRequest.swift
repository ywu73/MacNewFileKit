import Foundation

public struct FileCreationRequest: Equatable, Sendable {
    public let directoryURL: URL
    public let baseName: String
    public let fileExtension: String
    public let contents: Data

    public init(
        directoryURL: URL,
        baseName: String = "untitled",
        fileExtension: String,
        contents: Data = Data()
    ) {
        self.directoryURL = directoryURL
        self.baseName = baseName
        self.fileExtension = fileExtension
        self.contents = contents
    }
}

public struct CreatedFile: Equatable, Sendable {
    public let url: URL
    public let collisionIndex: Int

    public init(url: URL, collisionIndex: Int) {
        self.url = url
        self.collisionIndex = collisionIndex
    }
}
