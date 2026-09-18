import Foundation

public struct MarkdownBlock: Identifiable, Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case heading(Int), paragraph, quote, code(String), list(String), task(Bool), divider, table([[String]])
    }
    public let id: Int // Source line: also used by the outline and task toggles.
    public let kind: Kind
    public let text: String
}

public enum MarkdownParser {
    public static func parse(_ source: String) -> [MarkdownBlock] {
        let lines = source.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        var blocks: [MarkdownBlock] = []
        var index = 0
        func cells(_ line: String) -> [String] {
            var value = line.trimmingCharacters(in: .whitespaces)
            if value.hasPrefix("|") { value.removeFirst() }
            if value.hasSuffix("|") { value.removeLast() }
            return value.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
        }
        while index < lines.count {
            let start = index
            let line = lines[index].trimmingCharacters(in: .whitespaces)
            index += 1
            if line.isEmpty { continue }
            if line.hasPrefix("```") || line.hasPrefix("~~~") {
                let marker = String(line.prefix(while: { $0 == line.first! }))
                let language = String(line.dropFirst(marker.count)).trimmingCharacters(in: .whitespaces)
                var content: [String] = []
                while index < lines.count {
                    let closing = lines[index].trimmingCharacters(in: .whitespaces)
                    if closing.count >= marker.count && closing.allSatisfy({ $0 == marker.first! }) { index += 1; break }
                    content.append(lines[index]); index += 1
                }
                blocks.append(.init(id: start, kind: .code(language), text: content.joined(separator: "\n")))
            } else if line.hasPrefix("#"), line.prefix(while: { $0 == "#" }).count <= 6,
                      line.dropFirst(line.prefix(while: { $0 == "#" }).count).hasPrefix(" ") {
                let level = line.prefix(while: { $0 == "#" }).count
                blocks.append(.init(id: start, kind: .heading(level), text: String(line.dropFirst(level + 1))))
            } else if ["---", "***", "___"].contains(line.replacingOccurrences(of: " ", with: "")) {
                blocks.append(.init(id: start, kind: .divider, text: ""))
            } else if line.hasPrefix(">") {
                blocks.append(.init(id: start, kind: .quote, text: String(line.dropFirst()).trimmingCharacters(in: .whitespaces)))
            } else if line.range(of: #"^[-*+] \[[ xX]\] "#, options: .regularExpression) != nil {
                blocks.append(.init(id: start, kind: .task(line.lowercased().hasPrefix(String(line.prefix(2)) + "[x]")), text: String(line.dropFirst(6))))
            } else if let range = line.range(of: #"^([-*+] |[0-9]+[.)] )"#, options: .regularExpression) {
                let marker = String(line[range]).trimmingCharacters(in: .whitespaces)
                blocks.append(.init(id: start, kind: .list(marker.count == 1 ? "•" : marker), text: String(line[range.upperBound...])))
            } else if line.contains("|"), index < lines.count,
                      cells(lines[index]).allSatisfy({ $0.range(of: #"^:?-{3,}:?$"#, options: .regularExpression) != nil }),
                      cells(lines[index]).count == cells(line).count {
                var rows = [cells(line)]; index += 1
                while index < lines.count && lines[index].contains("|") && !lines[index].isEmpty {
                    rows.append(cells(lines[index])); index += 1
                }
                blocks.append(.init(id: start, kind: .table(rows), text: rows.map { $0.joined(separator: " | ") }.joined(separator: "\n")))
            } else {
                // Keep source line identity stable, including unsupported Markdown syntax.
                blocks.append(.init(id: start, kind: .paragraph, text: line))
            }
        }
        return blocks
    }

    public static func toggleTask(in source: String, line: Int) -> String {
        let newline = source.contains("\r\n") ? "\r\n" : "\n"
        var lines = source.components(separatedBy: newline)
        guard lines.indices.contains(line), let range = lines[line].range(of: #"^(\s*[-*+] )\[[ xX]\]"#, options: .regularExpression) else { return source }
        let token = String(lines[line][range])
        lines[line].replaceSubrange(range, with: token.replacingOccurrences(of: #"\[[ xX]\]"#, with: token.lowercased().contains("[x]") ? "[ ]" : "[x]", options: .regularExpression))
        return lines.joined(separator: newline)
    }
}

public struct DocumentStatistics: Equatable {
    public let characters: Int
    public let words: Int
    public var readingMinutes: Int { max(1, Int(ceil(Double(words) / 250))) }
    public init(_ text: String) {
        characters = text.count
        let cjk = text.unicodeScalars.filter { (0x3400...0x9FFF).contains($0.value) }.count
        let other = text.unicodeScalars.map { (0x3400...0x9FFF).contains($0.value) ? " " : String($0) }.joined()
        words = cjk + other.split(whereSeparator: { $0.isWhitespace || $0.isPunctuation }).count
    }
}
