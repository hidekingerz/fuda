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

@MainActor
final class FileHistoryTests: XCTestCase {
    func testSameContentWithDifferentTypeIsSeparateItem() throws {
        let container = try PersistenceController.inMemory()
        let store = HistoryStore(context: container.mainContext)
        try store.record("/tmp/a.txt", type: .text, at: Date(timeIntervalSince1970: 1))
        try store.record("/tmp/a.txt", type: .file, at: Date(timeIntervalSince1970: 2))
        let all = try store.fetchAll()
        XCTAssertEqual(all.count, 2)
        XCTAssertEqual(all.map(\.type), [.file, .text])
    }

    func testFileItemExposesURLsAndMissingState() throws {
        let existing = FileManager.default.temporaryDirectory.appendingPathComponent("fuda-\(UUID().uuidString).txt")
        try "x".write(to: existing, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: existing) }

        let item = ClipboardItem(content: ClipboardItem.fileContent(paths: [existing.path]), type: .file)
        XCTAssertEqual(item.fileURLs.map(\.path), [existing.path])
        XCTAssertFalse(item.hasMissingFile)

        let missing = ClipboardItem(content: "/nonexistent/fuda/file.txt", type: .file)
        XCTAssertTrue(missing.hasMissingFile)
        XCTAssertFalse(PanelEntry.history(missing).isPastable)
        XCTAssertEqual(PanelEntry.history(missing).title, "file.txt")
        XCTAssertEqual(PanelEntry.history(missing).subtitle, "/nonexistent/fuda")
    }

    func testTextItemsAreAlwaysPastable() {
        XCTAssertTrue(PanelEntry.history(ClipboardItem(content: "hello")).isPastable)
        XCTAssertNil(PanelEntry.history(ClipboardItem(content: "hello")).subtitle)
    }
}
