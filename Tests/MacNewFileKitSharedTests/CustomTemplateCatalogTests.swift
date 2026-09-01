import Foundation
import Testing
@testable import MacNewFileKitShared

@Suite("CustomTemplateCatalog")
struct CustomTemplateCatalogTests {
    @Test("normalizes and adds a custom template")
    func addsTemplate() throws {
        var catalog = CustomTemplateCatalog(templates: [])
        let template = try catalog.add(
            displayName: "  YAML  ",
            fileExtension: ".yaml",
            initialText: "---\n"
        )

        #expect(template.displayName == "YAML")
        #expect(template.fileExtension == "yaml")
        #expect(template.initialText == "---\n")
        #expect(catalog.templates == [template])
    }

    @Test("rejects duplicate names without case sensitivity")
    func rejectsDuplicateName() throws {
        var catalog = CustomTemplateCatalog(templates: [])
        try catalog.add(displayName: "YAML", fileExtension: "yaml")

        #expect(throws: CustomTemplateCatalogError.duplicateDisplayName("yaml")) {
            try catalog.add(displayName: "yaml", fileExtension: "yml")
        }
    }

    @Test("updates a template while preserving its identity")
    func updatesTemplate() throws {
        let original = CustomFileTemplate(displayName: "HTML", fileExtension: "html")
        var catalog = CustomTemplateCatalog(templates: [original])

        try catalog.update(
            id: original.id,
            displayName: "Web Page",
            fileExtension: "htm",
            initialText: "<!doctype html>\n"
        )

        #expect(catalog.templates.first?.id == original.id)
        #expect(catalog.templates.first?.displayName == "Web Page")
        #expect(catalog.templates.first?.initialText == "<!doctype html>\n")
    }

    @Test("duplicates with a unique name and new identity")
    func duplicatesTemplate() throws {
        let original = CustomFileTemplate(displayName: "HTML", fileExtension: "html")
        var catalog = CustomTemplateCatalog(templates: [original])

        let firstCopy = try catalog.duplicate(id: original.id)
        let secondCopy = try catalog.duplicate(id: original.id)

        #expect(firstCopy.id != original.id)
        #expect(firstCopy.displayName == "HTML Copy")
        #expect(secondCopy.displayName == "HTML Copy 2")
    }

    @Test("moves templates without leaving the valid range")
    func movesTemplate() throws {
        let first = CustomFileTemplate(displayName: "First", fileExtension: "one")
        let second = CustomFileTemplate(displayName: "Second", fileExtension: "two")
        var catalog = CustomTemplateCatalog(templates: [first, second])

        try catalog.move(id: second.id, offset: -1)
        try catalog.move(id: second.id, offset: -1)

        #expect(catalog.templates.map(\.id) == [second.id, first.id])
    }
}
