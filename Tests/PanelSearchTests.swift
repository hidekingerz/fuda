import XCTest
@testable import fuda

final class PanelSearchTests: XCTestCase {
    private let items = ["Hello World", "hello swift", "Goodbye", "swift ui world"]

    func testEmptyQueryReturnsEverything() {
        XCTAssertEqual(PanelSearch.filter(items, query: "   ", text: { $0 }), items)
    }

    func testCaseInsensitiveMatch() {
        XCTAssertEqual(PanelSearch.filter(items, query: "HELLO", text: { $0 }), ["Hello World", "hello swift"])
    }

    func testMultipleTermsAreAnded() {
        XCTAssertEqual(PanelSearch.filter(items, query: "swift world", text: { $0 }), ["swift ui world"])
    }

    func testFirstLine() {
        XCTAssertEqual("  first\nsecond".firstLine, "first")
        XCTAssertEqual("single".firstLine, "single")
    }
}

final class PanelSearchRankTests: XCTestCase {
    private struct Entry: Equatable {
        let text: String
        let keyword: String?
    }

    private let entries = [
        Entry(text: "signature history line", keyword: nil),
        Entry(text: "sig\nBest regards, hidekingerz", keyword: "sig"),
        Entry(text: "sig another", keyword: "sigx"),
    ]

    private func rank(_ query: String) -> [Entry] {
        PanelSearch.rank(entries, query: query, text: \.text, keyword: \.keyword)
    }

    func testExactKeywordMatchComesFirst() {
        XCTAssertEqual(rank("sig").first?.keyword, "sig")
        XCTAssertEqual(rank("sig").count, 3)
    }

    func testKeywordMatchIgnoresCaseAndSurroundingWhitespace() {
        XCTAssertEqual(rank(" SIG ").first?.keyword, "sig")
        XCTAssertTrue(PanelSearch.matchesKeyword("Sig", query: "sig"))
    }

    func testPartialKeywordIsNotPromoted() {
        XCTAssertEqual(rank("si").first?.keyword, nil)
        XCTAssertFalse(PanelSearch.matchesKeyword("sig", query: "si"))
        XCTAssertFalse(PanelSearch.matchesKeyword(nil, query: "sig"))
        XCTAssertFalse(PanelSearch.matchesKeyword("sig", query: ""))
    }

    func testEmptyQueryKeepsOriginalOrder() {
        XCTAssertEqual(rank(""), entries)
    }
}
