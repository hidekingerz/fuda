import SwiftData
import XCTest
@testable import fuda

@MainActor
final class HistoryStoreTests: XCTestCase {
    private var container: ModelContainer!
    private var store: HistoryStore!

    override func setUp() async throws {
        container = try PersistenceController.inMemory()
        store = HistoryStore(context: container.mainContext)
    }

    func testRecordInsertsNewestFirst() throws {
        try store.record("a", at: Date(timeIntervalSince1970: 1))
        try store.record("b", at: Date(timeIntervalSince1970: 2))
        XCTAssertEqual(try store.fetchAll().map(\.content), ["b", "a"])
    }

    func testRecordingDuplicateMovesItToTop() throws {
        try store.record("a", at: Date(timeIntervalSince1970: 1))
        try store.record("b", at: Date(timeIntervalSince1970: 2))
        try store.record("a", at: Date(timeIntervalSince1970: 3))
        let all = try store.fetchAll()
        XCTAssertEqual(all.map(\.content), ["a", "b"])
        XCTAssertEqual(all.count, 2)
    }

    func testPruneRemovesOldestBeyondLimit() throws {
        for i in 0..<5 {
            try store.record("item\(i)", at: Date(timeIntervalSince1970: TimeInterval(i)), limit: 3)
        }
        XCTAssertEqual(try store.fetchAll().map(\.content), ["item4", "item3", "item2"])
    }

    func testPinnedItemsSurvivePrune() throws {
        let pinned = try store.record("keep", at: Date(timeIntervalSince1970: 0), limit: 2)
        try store.togglePinned(pinned)
        for i in 1...4 {
            try store.record("item\(i)", at: Date(timeIntervalSince1970: TimeInterval(i)), limit: 2)
        }
        let contents = try store.fetchAll().map(\.content)
        XCTAssertEqual(contents, ["item4", "item3", "keep"])
    }
}
