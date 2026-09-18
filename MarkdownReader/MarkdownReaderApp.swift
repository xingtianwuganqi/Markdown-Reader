import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let markdownDocument = UTType(importedAs: "net.daringfireball.markdown", conformingTo: .plainText)
}

struct MarkdownDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.markdownDocument, .plainText] }
    static var writableContentTypes: [UTType] { [.markdownDocument] }
    var text: String
    private var encoding: String.Encoding = .utf8
    private var hasUTF8BOM = false
    init(text: String = "") { self.text = text }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        hasUTF8BOM = data.starts(with: [0xEF, 0xBB, 0xBF])
        if data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF]) {
            encoding = .utf16
        }
        guard let decoded = String(data: data, encoding: encoding) else { throw CocoaError(.fileReadInapplicableStringEncoding) }
        text = hasUTF8BOM ? String(decoded.drop(while: { $0 == "\u{FEFF}" })) : decoded
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard var data = text.data(using: encoding) else { throw CocoaError(.fileWriteInapplicableStringEncoding) }
        if hasUTF8BOM { data.insert(contentsOf: [0xEF, 0xBB, 0xBF], at: 0) }
        return FileWrapper(regularFileWithContents: data)
    }
}

@main
struct MarkdownReaderApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: MarkdownDocument()) { file in
            WorkspaceView(document: file.$document, fileURL: file.fileURL)
        }
        .defaultSize(width: 1120, height: 780)
    }
}
