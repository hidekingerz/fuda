import XCTest
@testable import fuda

final class ConfirmActionTests: XCTestCase {
    func testDefaultIsCopyOnly() {
        XCTAssertEqual(ConfirmAction.default, .copyOnly)
        XCTAssertEqual(ConfirmAction.resolve(nil), .copyOnly)
        XCTAssertEqual(ConfirmAction.resolve(""), .copyOnly)
        XCTAssertEqual(ConfirmAction.resolve("bogus"), .copyOnly)
    }

    func testResolveKnownValues() {
        XCTAssertEqual(ConfirmAction.resolve("paste"), .paste)
        XCTAssertEqual(ConfirmAction.resolve("copyOnly"), .copyOnly)
    }

    func testAlternateFlips() {
        XCTAssertEqual(ConfirmAction.paste.alternate, .copyOnly)
        XCTAssertEqual(ConfirmAction.copyOnly.alternate, .paste)
        for action in ConfirmAction.allCases {
            XCTAssertEqual(action.alternate.alternate, action)
        }
    }

    func testShiftSelectsAlternate() {
        XCTAssertEqual(ConfirmAction.action(enterAction: .copyOnly, shift: false), .copyOnly)
        XCTAssertEqual(ConfirmAction.action(enterAction: .copyOnly, shift: true), .paste)
        XCTAssertEqual(ConfirmAction.action(enterAction: .paste, shift: false), .paste)
        XCTAssertEqual(ConfirmAction.action(enterAction: .paste, shift: true), .copyOnly)
    }
}
