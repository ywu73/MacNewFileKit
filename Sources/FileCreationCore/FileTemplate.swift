import Foundation

public enum FileTemplate: String, CaseIterable, Codable, Identifiable, Sendable {
    case text
    case markdown
    case json
    case word
    case excel
    case powerPoint

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .text: "Text Document"
        case .markdown: "Markdown"
        case .json: "JSON"
        case .word: "Word Document"
        case .excel: "Excel Workbook"
        case .powerPoint: "PowerPoint Presentation"
        }
    }

    public var fileExtension: String {
        switch self {
        case .text: "txt"
        case .markdown: "md"
        case .json: "json"
        case .word: "docx"
        case .excel: "xlsx"
        case .powerPoint: "pptx"
        }
    }

    public var initialContents: Data {
        get throws {
            switch self {
            case .text, .markdown:
                return Data()
            case .json:
                return Data("{}\n".utf8)
            case .word:
                return try Self.bundledContents(named: "blank", fileExtension: "docx")
            case .excel:
                return try Self.bundledContents(named: "blank", fileExtension: "xlsx")
            case .powerPoint:
                return try Self.bundledContents(named: "blank", fileExtension: "pptx")
            }
        }
    }

    private static func bundledContents(
        named name: String,
        fileExtension: String
    ) throws -> Data {
        let filename = "\(name).\(fileExtension)"
        guard let url = Bundle.module.url(
            forResource: name,
            withExtension: fileExtension
        ) else {
            throw FileCreationError.missingTemplateResource(filename)
        }

        do {
            return try Data(contentsOf: url)
        } catch {
            throw FileCreationError.missingTemplateResource(filename)
        }
    }
}
