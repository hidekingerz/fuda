import AppKit
import Foundation
import SwiftData

/// パネルの状態。一覧・検索・選択・スニペットフォームを管理する。
@MainActor
final class PanelViewModel: ObservableObject {
    enum Mode: Equatable {
        case list
        case form(editing: Snippet?)
    }

    @Published var query: String = "" {
        didSet { applyFilter(resetSelection: true) }
    }
    @Published private(set) var results: [PanelEntry] = []
    /// 検索文字列とキーワードが完全一致している項目の ID。
    @Published private(set) var keywordMatches: Set<PanelEntry.ID> = []
    @Published var selectedIndex: Int = 0
    @Published var mode: Mode = .list
    @Published var errorMessage: String?
    @Published var sortOrder: PanelSortOrder = PanelSortOrder(
        rawValue: UserDefaults.standard.string(forKey: PanelSortOrder.defaultsKey) ?? ""
    ) ?? .newest {
        didSet {
            UserDefaults.standard.set(sortOrder.rawValue, forKey: PanelSortOrder.defaultsKey)
            applyFilter(resetSelection: true)
        }
    }
    /// 項目ごとの貼り付け回数と最終貼り付け日時。
    @Published private(set) var usage: [PanelEntry.ID: UsageStats] = [:]

    /// Enter で確定したときに呼ばれる。
    var onConfirm: ((PanelEntry) -> Void)?
    /// Esc で閉じるときに呼ばれる。
    var onDismiss: (() -> Void)?

    private let historyStore: HistoryStore
    private let snippetStore: SnippetStore
    private let pasteEventStore: PasteEventStore
    private var allEntries: [PanelEntry] = []

    init(context: ModelContext) {
        self.historyStore = HistoryStore(context: context)
        self.snippetStore = SnippetStore(context: context)
        self.pasteEventStore = PasteEventStore(context: context)
    }

    var selectedEntry: PanelEntry? {
        results.indices.contains(selectedIndex) ? results[selectedIndex] : nil
    }

    // MARK: - 読み込み・検索

    func reload() {
        do {
            let snippets = try snippetStore.fetchAll().map(PanelEntry.snippet)
            let history = try historyStore.fetchAll().map(PanelEntry.history)
            // pinned → スニペット → 通常の履歴 の順
            let pinned = history.filter(\.isPinned)
            let unpinned = history.filter { !$0.isPinned }
            allEntries = pinned + snippets + unpinned
            let stats = try pasteEventStore.usageStats()
            usage = Dictionary(uniqueKeysWithValues: allEntries.compactMap { entry in
                stats[PasteEvent.encode(entry.id)].map { (entry.id, $0) }
            })
            applyFilter(resetSelection: false)
        } catch {
            errorMessage = "読み込みに失敗しました: \(error.localizedDescription)"
        }
    }

    func resetForShow() {
        query = ""
        mode = .list
        errorMessage = nil
        reload()
        selectedIndex = 0
    }

    private func applyFilter(resetSelection: Bool) {
        let sorted = sortOrder.sort(allEntries) { usage[$0.id] ?? UsageStats() }
        results = PanelSearch.rank(sorted, query: query, text: \.searchableText, keyword: \.keyword)
        keywordMatches = Set(results.filter { PanelSearch.matchesKeyword($0.keyword, query: query) }.map(\.id))
        if resetSelection || !results.indices.contains(selectedIndex) {
            selectedIndex = 0
        }
    }

    // MARK: - キー操作

    func moveSelection(by delta: Int) {
        guard !results.isEmpty else { return }
        selectedIndex = min(max(selectedIndex + delta, 0), results.count - 1)
    }

    func confirmSelection() {
        guard let entry = selectedEntry else { return }
        guard entry.isPastable else {
            errorMessage = "ファイルが見つからないため貼り付けできません"
            return
        }
        onConfirm?(entry)
    }

    func dismiss() {
        onDismiss?()
    }

    // MARK: - 履歴操作

    func delete(_ entry: PanelEntry) {
        do {
            try pasteEventStore.delete(for: entry.id)
            switch entry {
            case .history(let item): try historyStore.delete(item)
            case .snippet(let snippet): try snippetStore.delete(snippet)
            }
            reload()
        } catch {
            errorMessage = "削除に失敗しました: \(error.localizedDescription)"
        }
    }

    func togglePinned(_ entry: PanelEntry) {
        guard case .history(let item) = entry else { return }
        do {
            try historyStore.togglePinned(item)
            reload()
        } catch {
            errorMessage = "更新に失敗しました: \(error.localizedDescription)"
        }
    }

    // MARK: - 貼り付けイベント

    func recordPaste(of entry: PanelEntry, to bundleID: String?) {
        do {
            try pasteEventStore.record(targetID: entry.id, targetBundleID: bundleID)
        } catch {
            NSLog("貼り付けイベントの記録に失敗: \(error)")
        }
    }

    func usageCount(for entry: PanelEntry) -> Int {
        usage[entry.id]?.count ?? 0
    }

    // MARK: - スニペットフォーム

    func beginNewSnippet() {
        mode = .form(editing: nil)
    }

    func beginEditSelectedSnippet() {
        guard case .snippet(let snippet)? = selectedEntry else { return }
        mode = .form(editing: snippet)
    }

    func beginEdit(_ snippet: Snippet) {
        mode = .form(editing: snippet)
    }

    func cancelForm() {
        mode = .list
    }

    func saveSnippet(editing snippet: Snippet?, title: String, content: String, keyword: String) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, !content.isEmpty else {
            errorMessage = "タイトルと内容は必須です"
            return
        }
        do {
            if let snippet {
                try snippetStore.update(snippet, title: trimmedTitle, content: content, keyword: keyword)
            } else {
                try snippetStore.create(title: trimmedTitle, content: content, keyword: keyword)
            }
            errorMessage = nil
            mode = .list
            reload()
        } catch {
            errorMessage = "保存に失敗しました: \(error.localizedDescription)"
        }
    }
}
