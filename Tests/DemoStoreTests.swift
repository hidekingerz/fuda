import SwiftData
import XCTest
@testable import fuda

/// README 用スクリーンショットのデモデータを作る。
/// `TEST_RUNNER_FUDA_DEMO_STORE=/path/to/demo.store` を付けて実行したときだけ動く。
@MainActor
final class DemoStoreTests: XCTestCase {
    func testSeedDemoStore() throws {
        guard let path = ProcessInfo.processInfo.environment["FUDA_DEMO_STORE"], !path.isEmpty else {
            throw XCTSkip("FUDA_DEMO_STORE が未指定")
        }
        let url = URL(fileURLWithPath: path)
        try? FileManager.default.removeItem(at: url)
        let container = try ModelContainer(for: PersistenceController.schema, configurations: ModelConfiguration(url: url))
        let history = HistoryStore(context: container.mainContext)
        let snippets = SnippetStore(context: container.mainContext)

        try snippets.create(title: "メールの署名", content: "--\n片桐 秀樹\nhidekingerz@example.com", keyword: "sig")
        try snippets.create(title: "レビュー依頼", content: "お手すきの際にレビューをお願いします。", keyword: "rev")
        try snippets.create(title: "日付フォーマット", content: "yyyy-MM-dd HH:mm", keyword: nil)

        let base = Date(timeIntervalSinceNow: -3600)
        let texts = [
            "git switch -c feature/panel-text-size",
            "https://github.com/hidekingerz/fuda",
            "xcodegen generate && open fuda.xcodeproj",
            "クリップボード履歴とスニペットを横断して検索できます",
            "brew install xcodegen",
            "let panel = NSPanel(contentRect: rect, styleMask: [.nonactivatingPanel, .titled], backing: .buffered, defer: false)",
        ]
        for (i, text) in texts.enumerated() {
            try history.record(text, at: base.addingTimeInterval(TimeInterval(i * 60)))
        }
        let pinned = try history.record("会議室の予約: https://example.com/rooms/4F-A", at: base.addingTimeInterval(-600))
        try history.togglePinned(pinned)
        try history.record("/Applications/Safari.app", type: .file, at: base.addingTimeInterval(400))
    }
}
