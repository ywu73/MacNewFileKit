import Darwin
import Foundation

public struct FileCreator: Sendable {
    public let maximumCollisionAttempts: Int

    public init(maximumCollisionAttempts: Int = 10_000) {
        self.maximumCollisionAttempts = maximumCollisionAttempts
    }

    public func create(_ request: FileCreationRequest) throws -> CreatedFile {
        let directoryURL = request.directoryURL.standardizedFileURL
        try validateDirectory(directoryURL)

        guard maximumCollisionAttempts > 0 else {
            throw FileCreationError.tooManyNameCollisions(directoryURL)
        }

        let baseName = try FileNamePolicy.normalizedBaseName(request.baseName)
        let fileExtension = try FileNamePolicy.normalizedFileExtension(request.fileExtension)

        for collisionIndex in 1...maximumCollisionAttempts {
            let filename = candidateFilename(
                baseName: baseName,
                fileExtension: fileExtension,
                collisionIndex: collisionIndex
            )
            let fileURL = directoryURL.appendingPathComponent(filename, isDirectory: false)

            do {
                try createExclusively(at: fileURL, contents: request.contents)
                return CreatedFile(url: fileURL, collisionIndex: collisionIndex)
            } catch let error as POSIXCreationError where error.code == EEXIST {
                continue
            } catch let error as POSIXCreationError {
                throw mapPOSIXError(error.code, fileURL: fileURL, directoryURL: directoryURL)
            }
        }

        throw FileCreationError.tooManyNameCollisions(directoryURL)
    }

    public func request(
        for template: FileTemplate,
        in directoryURL: URL,
        baseName: String = "untitled"
    ) -> FileCreationRequest {
        FileCreationRequest(
            directoryURL: directoryURL,
            baseName: baseName,
            fileExtension: template.fileExtension,
            contents: template.initialContents
        )
    }

    private func validateDirectory(_ url: URL) throws {
        guard url.isFileURL else {
            throw FileCreationError.invalidDirectory(url)
        }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue
        else {
            throw FileCreationError.invalidDirectory(url)
        }
    }

    private func candidateFilename(
        baseName: String,
        fileExtension: String,
        collisionIndex: Int
    ) -> String {
        if collisionIndex == 1 {
            return "\(baseName).\(fileExtension)"
        }
        return "\(baseName) \(collisionIndex).\(fileExtension)"
    }

    private func createExclusively(at url: URL, contents: Data) throws {
        let path = url.path
        let descriptor = path.withCString { pointer in
            Darwin.open(pointer, O_WRONLY | O_CREAT | O_EXCL, mode_t(0o644))
        }

        guard descriptor >= 0 else {
            throw POSIXCreationError(code: errno)
        }

        var shouldRemovePartialFile = false
        defer {
            Darwin.close(descriptor)
            if shouldRemovePartialFile {
                path.withCString { pointer in
                    _ = Darwin.unlink(pointer)
                }
            }
        }

        do {
            try write(contents, to: descriptor)
        } catch {
            shouldRemovePartialFile = true
            throw error
        }
    }

    private func write(_ data: Data, to descriptor: Int32) throws {
        try data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return }
            var totalWritten = 0

            while totalWritten < rawBuffer.count {
                let result = Darwin.write(
                    descriptor,
                    baseAddress.advanced(by: totalWritten),
                    rawBuffer.count - totalWritten
                )

                if result < 0 {
                    if errno == EINTR { continue }
                    throw POSIXCreationError(code: errno)
                }
                if result == 0 {
                    throw POSIXCreationError(code: EIO)
                }
                totalWritten += result
            }
        }
    }

    private func mapPOSIXError(
        _ code: Int32,
        fileURL: URL,
        directoryURL: URL
    ) -> FileCreationError {
        switch code {
        case EACCES, EPERM:
            .permissionDenied(directoryURL)
        case EROFS:
            .readOnlyFileSystem(directoryURL)
        default:
            .systemError(path: fileURL.path, code: code)
        }
    }
}

private struct POSIXCreationError: Error {
    let code: Int32
}
