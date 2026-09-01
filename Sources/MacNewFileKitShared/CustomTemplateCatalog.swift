import FileCreationCore
import Foundation

public enum CustomTemplateCatalogError: Error, Equatable, Sendable {
    case emptyDisplayName
    case duplicateDisplayName(String)
    case missingTemplate(UUID)
}

extension CustomTemplateCatalogError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .emptyDisplayName:
            "The custom template name cannot be empty."
        case let .duplicateDisplayName(name):
            "A custom template named \"\(name)\" already exists."
        case .missingTemplate:
            "The custom template no longer exists."
        }
    }
}

public struct CustomTemplateCatalog: Equatable, Sendable {
    public private(set) var templates: [CustomFileTemplate]

    public init(templates: [CustomFileTemplate]) {
        self.templates = templates
    }

    @discardableResult
    public mutating func add(
        displayName: String,
        fileExtension: String,
        initialText: String = ""
    ) throws -> CustomFileTemplate {
        let template = try validatedTemplate(
            id: UUID(),
            displayName: displayName,
            fileExtension: fileExtension,
            initialText: initialText,
            excluding: nil
        )
        templates.append(template)
        return template
    }

    public mutating func update(
        id: UUID,
        displayName: String,
        fileExtension: String,
        initialText: String
    ) throws {
        guard let index = templates.firstIndex(where: { $0.id == id }) else {
            throw CustomTemplateCatalogError.missingTemplate(id)
        }

        templates[index] = try validatedTemplate(
            id: id,
            displayName: displayName,
            fileExtension: fileExtension,
            initialText: initialText,
            excluding: id
        )
    }

    @discardableResult
    public mutating func duplicate(id: UUID) throws -> CustomFileTemplate {
        guard let source = templates.first(where: { $0.id == id }) else {
            throw CustomTemplateCatalogError.missingTemplate(id)
        }

        let displayName = uniqueCopyName(for: source.displayName)
        let copy = CustomFileTemplate(
            displayName: displayName,
            fileExtension: source.fileExtension,
            initialText: source.initialText
        )
        templates.append(copy)
        return copy
    }

    public mutating func remove(id: UUID) throws {
        guard let index = templates.firstIndex(where: { $0.id == id }) else {
            throw CustomTemplateCatalogError.missingTemplate(id)
        }
        templates.remove(at: index)
    }

    public mutating func move(id: UUID, offset: Int) throws {
        guard let sourceIndex = templates.firstIndex(where: { $0.id == id }) else {
            throw CustomTemplateCatalogError.missingTemplate(id)
        }

        let destinationIndex = sourceIndex + offset
        guard templates.indices.contains(destinationIndex) else { return }
        templates.swapAt(sourceIndex, destinationIndex)
    }

    private func validatedTemplate(
        id: UUID,
        displayName: String,
        fileExtension: String,
        initialText: String,
        excluding excludedID: UUID?
    ) throws -> CustomFileTemplate {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            throw CustomTemplateCatalogError.emptyDisplayName
        }

        if templates.contains(where: {
            $0.id != excludedID && $0.displayName.caseInsensitiveCompare(name) == .orderedSame
        }) {
            throw CustomTemplateCatalogError.duplicateDisplayName(name)
        }

        return CustomFileTemplate(
            id: id,
            displayName: name,
            fileExtension: try FileNamePolicy.normalizedFileExtension(fileExtension),
            initialText: initialText
        )
    }

    private func uniqueCopyName(for sourceName: String) -> String {
        let baseName = "\(sourceName) Copy"
        var candidate = baseName
        var index = 2

        while templates.contains(where: {
            $0.displayName.caseInsensitiveCompare(candidate) == .orderedSame
        }) {
            candidate = "\(baseName) \(index)"
            index += 1
        }
        return candidate
    }
}
