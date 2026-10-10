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
