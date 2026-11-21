import SwiftData
import XCTest
@testable import fuda

final class PanelTabTests: XCTestCase {
    func testResolveDefaultsToHistory() {
        XCTAssertEqual(PanelTab.resolve(nil), .history)
        XCTAssertEqual(PanelTab.resolve("bogus"), .history)
        XCTAssertEqual(PanelTab.resolve("snippets"), .snippets)
    }

    func testOtherFlips() {
        XCTAssertEqual(PanelTab.history.other, .snippets)
        XCTAssertEqual(PanelTab.snippets.other, .history)
    }

    func testSortIsResolvedPerTab() {
        XCTAssertEqual(PanelTab.history.resolveSort(nil), .newest)
        XCTAssertEqual(PanelTab.snippets.resolveSort(nil), .mostUsed)
        // 履歴では名前順を選べない
        XCTAssertEqual(PanelTab.history.resolveSort("title"), .newest)
        // スニペットでは最近貼り付けた順を選べない
        XCTAssertEqual(PanelTab.snippets.resolveSort("recentlyPasted"), .mostUsed)
        XCTAssertEqual(PanelTab.snippets.resolveSort("title"), .title)
    }

    func testSortKeysAreSeparate() {
        XCTAssertNotEqual(PanelTab.history.sortDefaultsKey, PanelTab.snippets.sortDefaultsKey)
    }

    func testNewestIsCalledUpdatedInSnippets() {
        XCTAssertEqual(PanelSortOrder.newest.label(in: .history), "新しい順")
        XCTAssertEqual(PanelSortOrder.newest.label(in: .snippets), "更新順")
    }

    func testTitleSortUsesNaturalOrderAndIsStable() {
        let items = ["b", "a10", "a2", "B"]
        let sorted = PanelSortOrder.title.sort(items, stats: { _ in UsageStats() }, title: { $0 })
        XCTAssertEqual(sorted.prefix(2), ["a2", "a10"])
        XCTAssertEqual(Set(sorted.suffix(2)), ["b", "B"])
    }
}

final class RelativeTimeTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    func testBuckets() {
        XCTAssertEqual(RelativeTime.text(for: now.addingTimeInterval(-5), now: now), "今")
        XCTAssertEqual(RelativeTime.text(for: now.addingTimeInterval(-180), now: now), "3分前")
        XCTAssertEqual(RelativeTime.text(for: now.addingTimeInterval(-7200), now: now), "2時間前")
        XCTAssertEqual(RelativeTime.text(for: now.addingTimeInterval(-86400 * 3), now: now), "3日前")
    }

    func testOlderThanAWeekShowsDate() {
        let old = now.addingTimeInterval(-86400 * 30)
        XCTAssertEqual(RelativeTime.text(for: old, now: now), RelativeTime.shortDate(old))
        XCTAssertTrue(RelativeTime.shortDate(old).hasSuffix("日"))
    }

    func testFutureDateIsNow() {
        XCTAssertEqual(RelativeTime.text(for: now.addingTimeInterval(30), now: now), "今")
    }
}

@MainActor
final class PanelViewModelTabTests: XCTestCase {
    private var container: ModelContainer!
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var viewModel: PanelViewModel!

    override func setUp() async throws {
        container = try PersistenceController.inMemory()
        suiteName = "fuda.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        let history = HistoryStore(context: container.mainContext)
        let snippets = SnippetStore(context: container.mainContext)
        try history.record("signature in history")
        try history.record("brew install xcodegen")
        _ = try snippets.create(title: "メールの署名", content: "--\nhidekingerz", keyword: "sig")
        viewModel = PanelViewModel(context: container.mainContext, defaults: defaults)
        viewModel.resetForShow()
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testStartsInHistoryAndShowsOnlyHistory() {
        XCTAssertEqual(viewModel.tab, .history)
        XCTAssertEqual(viewModel.results.count, 2)
        XCTAssertTrue(viewModel.results.allSatisfy { !$0.isSnippet })
    }

    func testSwitchingTabShowsOnlySnippetsAndIsRemembered() {
        viewModel.toggleTab()
        XCTAssertEqual(viewModel.tab, .snippets)
        XCTAssertEqual(viewModel.results.map(\.title), ["メールの署名"])
        XCTAssertEqual(defaults.string(forKey: PanelTab.defaultsKey), "snippets")

        let reopened = PanelViewModel(context: container.mainContext, defaults: defaults)
        XCTAssertEqual(reopened.tab, .snippets)
    }

    func testOtherTabMatchCount() {
        viewModel.query = "hidekingerz"
        XCTAssertTrue(viewModel.results.isEmpty)
        XCTAssertEqual(viewModel.otherTabMatchCount, 1)

        viewModel.query = "sig"
        XCTAssertEqual(viewModel.results.count, 1)
        XCTAssertEqual(viewModel.otherTabMatchCount, 1)

        viewModel.query = ""
        XCTAssertEqual(viewModel.otherTabMatchCount, 0)
    }

    func testShowWithTabOverridesRememberedTab() {
        viewModel.resetForShow(tab: .snippets)
        XCTAssertEqual(viewModel.tab, .snippets)
    }

    func testSortOrderIsPerTab() {
        viewModel.sortOrder = .mostUsed
        viewModel.toggleTab()
        viewModel.sortOrder = .title
        viewModel.toggleTab()
        XCTAssertEqual(viewModel.sortOrder, .mostUsed)
        XCTAssertEqual(defaults.string(forKey: PanelTab.snippets.sortDefaultsKey), "title")
    }

    func testSnippetFromHistoryPrefillsAndSwitchesTab() throws {
        let entry = try XCTUnwrap(viewModel.results.first { $0.title == "brew install xcodegen" })
        viewModel.beginSnippet(from: entry)
        XCTAssertEqual(viewModel.tab, .snippets)
        XCTAssertEqual(viewModel.mode, .form(editing: nil, prefill: "brew install xcodegen"))

        viewModel.saveSnippet(editing: nil, title: "xcodegen", content: "brew install xcodegen", keyword: "")
        XCTAssertEqual(viewModel.mode, .list)
        XCTAssertEqual(viewModel.selectedEntry?.title, "xcodegen")
    }

    func testEditShortcutOnlyWorksInSnippets() {
        viewModel.beginEditSelectedSnippet()
        XCTAssertEqual(viewModel.mode, .list)
        viewModel.toggleTab()
        viewModel.beginEditSelectedSnippet()
        if case .form(let editing, _) = viewModel.mode {
            XCTAssertEqual(editing?.title, "メールの署名")
        } else {
            XCTFail("フォームが開いていない")
        }
    }
}
