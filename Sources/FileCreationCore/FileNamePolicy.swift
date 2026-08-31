import Foundation

public enum FileNamePolicy {
    public static func normalizedBaseName(_ value: String) throws -> String {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty,
              normalized != ".",
              normalized != "..",
              !containsPathSeparator(normalized)
        else {
            throw FileCreationError.invalidBaseName(value)
        }
        return normalized
    }

    public static func normalizedFileExtension(_ value: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = String(trimmed.drop(while: { $0 == "." }))
        guard !normalized.isEmpty,
              !containsPathSeparator(normalized),
              !normalized.contains(".")
        else {
            throw FileCreationError.invalidFileExtension(value)
        }
        return normalized
    }

    private static func containsPathSeparator(_ value: String) -> Bool {
        value.contains("/") || value.contains(":") || value.unicodeScalars.contains("\0")
    }
}
