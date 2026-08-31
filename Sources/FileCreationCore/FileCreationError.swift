import Foundation

public enum FileCreationError: Error, Equatable, Sendable {
    case invalidDirectory(URL)
    case invalidBaseName(String)
    case invalidFileExtension(String)
    case permissionDenied(URL)
    case readOnlyFileSystem(URL)
    case tooManyNameCollisions(URL)
    case systemError(path: String, code: Int32)
}

extension FileCreationError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .invalidDirectory(url):
            "The target is not a writable directory: \(url.path)"
        case let .invalidBaseName(name):
            "The base name is invalid: \(name)"
        case let .invalidFileExtension(fileExtension):
            "The file extension is invalid: \(fileExtension)"
        case let .permissionDenied(url):
            "Permission was denied while creating a file in: \(url.path)"
        case let .readOnlyFileSystem(url):
            "The target file system is read-only: \(url.path)"
        case let .tooManyNameCollisions(url):
            "No available file name could be found in: \(url.path)"
        case let .systemError(path, code):
            "The system could not create \(path) (errno \(code))."
        }
    }
}
