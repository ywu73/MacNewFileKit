import Foundation

public enum FileTemplate: String, CaseIterable, Codable, Identifiable, Sendable {
    case text
    case markdown
    case json

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .text: "Text Document"
        case .markdown: "Markdown"
        case .json: "JSON"
        }
    }

    public var fileExtension: String {
        switch self {
        case .text: "txt"
        case .markdown: "md"
        case .json: "json"
        }
    }

    public var initialContents: Data {
        switch self {
        case .text, .markdown:
            Data()
        case .json:
            Data("{}\n".utf8)
        }
    }
}
