import SwiftData
import XCTest
@testable import fuda

@MainActor
final class PasteEventStoreTests: XCTestCase {
    private var container: ModelContainer!
    private var events: PasteEventStore!
    private var history: HistoryStore!
    private var snippets: SnippetStore!

    override func setUp() async throws {
        container = try PersistenceController.inMemory()
        events = PasteEventStore(context: container.mainContext)
        history = HistoryStore(context: container.mainContext)
        snippets = SnippetStore(context: container.mainContext)
    }

    func testUsageStatsCountsAndLastPastedAt() throws {
        let a = try history.record("a")
        let b = try history.record("b")
        try events.record(targetID: a.persistentModelID, targetBundleID: "com.apple.Notes", at: Date(timeIntervalSince1970: 1))
        try events.record(targetID: a.persistentModelID, targetBundleID: nil, at: Date(timeIntervalSince1970: 5))
        try events.record(targetID: b.persistentModelID, targetBundleID: nil, at: Date(timeIntervalSince1970: 3))

        XCTAssertEqual(try events.usageStats(for: a.persistentModelID), UsageStats(count: 2, lastPastedAt: Date(timeIntervalSince1970: 5)))
        XCTAssertEqual(try events.usageStats(for: b.persistentModelID), UsageStats(count: 1, lastPastedAt: Date(timeIntervalSince1970: 3)))
        XCTAssertEqual(try events.usageStats().count, 2)
    }

    func testPruneRemovesEventsOlderThanRetention() throws {
        let a = try history.record("a")
        let now = Date(timeIntervalSince1970: 100 * 86_400)
        try events.record(targetID: a.persistentModelID, targetBundleID: nil, at: now.addingTimeInterval(-95 * 86_400))
        try events.record(targetID: a.persistentModelID, targetBundleID: nil, at: now.addingTimeInterval(-10 * 86_400))
        try events.prune(olderThan: 90, now: now)
        XCTAssertEqual(try events.count(), 1)
    }

    func testPruneOrphansDropsEventsWhoseTargetIsGone() throws {
        let a = try history.record("a")
        let s = try snippets.create(title: "t", content: "c", keyword: nil)
        try events.record(targetID: a.persistentModelID, targetBundleID: nil)
        try events.record(targetID: s.persistentModelID, targetBundleID: nil)
        try history.delete(a)
        try events.pruneOrphans()
        let remaining = try events.fetchAll()
        XCTAssertEqual(remaining.map(\.targetIDData), [PasteEvent.encode(s.persistentModelID)])
    }

    func testDeleteForTargetAndDeleteAll() throws {
        let a = try history.record("a")
        let b = try history.record("b")
        try events.record(targetID: a.persistentModelID, targetBundleID: nil)
        try events.record(targetID: b.persistentModelID, targetBundleID: nil)
        try events.delete(for: a.persistentModelID)
        XCTAssertEqual(try events.count(), 1)
        try events.deleteAll()
        XCTAssertEqual(try events.count(), 0)
    }
}

final class PanelSortOrderTests: XCTestCase {
    private let items = ["a", "b", "c", "d"]
    private let stats: [String: UsageStats] = [
        "b": UsageStats(count: 3, lastPastedAt: Date(timeIntervalSince1970: 10)),
        "c": UsageStats(count: 3, lastPastedAt: Date(timeIntervalSince1970: 20)),
        "d": UsageStats(count: 1, lastPastedAt: Date(timeIntervalSince1970: 30)),
    ]

    private func sorted(_ order: PanelSortOrder) -> [String] {
        order.sort(items) { stats[$0] ?? UsageStats() }
    }

    func testNewestKeepsInputOrder() {
        XCTAssertEqual(sorted(.newest), items)
    }

    func testMostUsedSortsByCountThenRecency() {
        XCTAssertEqual(sorted(.mostUsed), ["c", "b", "d", "a"])
    }

    func testRecentlyPastedPutsNeverPastedLast() {
        XCTAssertEqual(sorted(.recentlyPasted), ["d", "c", "b", "a"])
    }
}
