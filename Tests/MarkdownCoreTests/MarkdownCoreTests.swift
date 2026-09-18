import XCTest
@testable import MarkdownCore

final class MarkdownCoreTests: XCTestCase {
    func testHeadingsIgnoreFencedCodeAndKeepSourceLines() {
        let blocks = MarkdownParser.parse("# Title\n\n```swift\n# not a heading\n```\n## Section")
        XCTAssertEqual(blocks.map(\.id), [0, 2, 5])
        XCTAssertEqual(blocks.map(\.kind), [.heading(1), .code("swift"), .heading(2)])
        XCTAssertEqual(blocks[1].text, "# not a heading")
    }
    func testLongFenceDoesNotCloseOnShorterFence() {
        let blocks = MarkdownParser.parse("````md\n```swift\nlet x = 1\n```\n````")
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].text, "```swift\nlet x = 1\n```")
    }
    func testTaskTogglePreservesIndentationAndNewlines() {
        let source = "# Tasks\r\n\r\n  - [ ] Buy milk\r\n"
        let task = MarkdownParser.parse(source).last!
        XCTAssertEqual(task.id, 2)
        XCTAssertEqual(task.kind, .task(false))
        let changed = MarkdownParser.toggleTask(in: source, line: task.id)
        XCTAssertEqual(changed, "# Tasks\r\n\r\n  - [x] Buy milk\r\n")
        XCTAssertEqual(MarkdownParser.toggleTask(in: changed, line: task.id), source)
        XCTAssertEqual(MarkdownParser.toggleTask(in: source, line: 42), source)
    }
    func testTablesAndLists() {
        let blocks = MarkdownParser.parse("| A | B |\n| :--- | ---: |\n| one | two |\n\n1. First\n- Other\n* [X] Done")
        XCTAssertEqual(blocks[0].kind, .table([["A", "B"], ["one", "two"]]))
        XCTAssertEqual(blocks[1].kind, .list("1."))
        XCTAssertEqual(blocks[2].kind, .list("•"))
        XCTAssertEqual(blocks[3].kind, .task(true))
    }
    func testMalformedTableRemainsText() {
        XCTAssertEqual(MarkdownParser.parse("A | B\n-- | --").first?.kind, .paragraph)
    }
    func testEmptyAndUnterminatedFence() {
        XCTAssertTrue(MarkdownParser.parse("").isEmpty)
        XCTAssertEqual(MarkdownParser.parse("~~~\nhello").first?.text, "hello")
        XCTAssertEqual(MarkdownParser.parse("####### invalid").first?.kind, .paragraph)
    }
    func testChineseAndEnglishStatistics() {
        let stats = DocumentStatistics("你好 hello world")
        XCTAssertEqual(stats.words, 4)
        XCTAssertEqual(stats.characters, 14)
        XCTAssertEqual(stats.readingMinutes, 1)
        XCTAssertEqual(DocumentStatistics(String(repeating: "word ", count: 501)).readingMinutes, 3)
    }
    func testNonTaskIsNeverChanged() {
        let source = "a [ ] marker\n```\nhello\n```"
        XCTAssertEqual(MarkdownParser.toggleTask(in: source, line: 0), source)
    }
}
