import AppKit
import Foundation
import SwiftData

/// パネルの状態。モード（履歴／スニペット）・検索・選択・スニペットフォームを管理する。
@MainActor
final class PanelViewModel: ObservableObject {
    enum Mode: Equatable {
        case list
        /// prefill は履歴からスニペットを作るときの初期内容。
        case form(editing: Snippet?, prefill: String?)
    }

    @Published var query: String = "" {
        didSet { applyFilter(resetSelection: true) }
    }
    /// 今表示しているモード。最後に開いていたモードを覚える。
    @Published var tab: PanelTab {
        didSet {
            guard tab != oldValue else { return }
            defaults.set(tab.rawValue, forKey: PanelTab.defaultsKey)
            applyFilter(resetSelection: true)
        }
    }
    @Published private(set) var results: [PanelEntry] = []
    /// 検索中に、もう一方のモードで一致する件数。
    @Published private(set) var otherTabMatchCount = 0
    /// 検索文字列とキーワードが完全一致している項目の ID。
    @Published private(set) var keywordMatches: Set<PanelEntry.ID> = []
    @Published var selectedIndex: Int = 0
    @Published var mode: Mode = .list
    @Published var errorMessage: String?
    @Published private(set) var historySort: PanelSortOrder
    @Published private(set) var snippetSort: PanelSortOrder
    /// 項目ごとの貼り付け回数と最終貼り付け日時。
    @Published private(set) var usage: [PanelEntry.ID: UsageStats] = [:]

    /// 項目を確定したときに呼ばれる。action は貼り付けかコピーのみか。
    var onConfirm: ((PanelEntry, ConfirmAction) -> Void)?
    /// Esc で閉じるときに呼ばれる。
    var onDismiss: (() -> Void)?

    private let historyStore: HistoryStore
    private let snippetStore: SnippetStore
    private let pasteEventStore: PasteEventStore
    private let defaults: UserDefaults
    private var historyEntries: [PanelEntry] = []
    private var snippetEntries: [PanelEntry] = []

    init(context: ModelContext, defaults: UserDefaults = .standard) {
        self.historyStore = HistoryStore(context: context)
        self.snippetStore = SnippetStore(context: context)
        self.pasteEventStore = PasteEventStore(context: context)
        self.defaults = defaults
        self.tab = PanelTab.resolve(defaults.string(forKey: PanelTab.defaultsKey))
        self.historySort = PanelTab.history.resolveSort(defaults.string(forKey: PanelTab.history.sortDefaultsKey))
        self.snippetSort = PanelTab.snippets.resolveSort(defaults.string(forKey: PanelTab.snippets.sortDefaultsKey))
    }

    /// 今のモードの並び順。
    var sortOrder: PanelSortOrder {
        get { tab == .history ? historySort : snippetSort }
        set {
            switch tab {
            case .history: historySort = newValue
            case .snippets: snippetSort = newValue
            }
            defaults.set(newValue.rawValue, forKey: tab.sortDefaultsKey)
            applyFilter(resetSelection: true)
        }
    }

    var selectedEntry: PanelEntry? {
        results.indices.contains(selectedIndex) ? results[selectedIndex] : nil
    }

    // MARK: - 読み込み・検索

    func reload() {
        do {
            snippetEntries = try snippetStore.fetchAll().map(PanelEntry.snippet)
            let history = try historyStore.fetchAll().map(PanelEntry.history)
            // ピン留め → 通常の履歴 の順
            historyEntries = history.filter(\.isPinned) + history.filter { !$0.isPinned }
            let stats = try pasteEventStore.usageStats()
            usage = Dictionary(uniqueKeysWithValues: (historyEntries + snippetEntries).compactMap { entry in
                stats[PasteEvent.encode(entry.id)].map { (entry.id, $0) }
            })
            applyFilter(resetSelection: false)
        } catch {
            errorMessage = "読み込みに失敗しました: \(error.localizedDescription)"
        }
    }

    /// パネルを開く直前に呼ぶ。tab を渡すとそのモードで開き、省略すると前回のモードのまま。
    func resetForShow(tab: PanelTab? = nil) {
        query = ""
        if let tab { self.tab = tab }
        mode = .list
        errorMessage = nil
        reload()
        selectedIndex = 0
    }

    private func entries(for tab: PanelTab) -> [PanelEntry] {
        tab == .history ? historyEntries : snippetEntries
    }

    private func applyFilter(resetSelection: Bool) {
        let sorted = sortOrder.sort(entries(for: tab), stats: { usage[$0.id] ?? UsageStats() }, title: \.title)
        results = PanelSearch.rank(sorted, query: query, text: \.searchableText, keyword: \.keyword)
        keywordMatches = Set(results.filter { PanelSearch.matchesKeyword($0.keyword, query: query) }.map(\.id))
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        otherTabMatchCount = trimmed.isEmpty
            ? 0
            : PanelSearch.filter(entries(for: tab.other), query: query, text: \.searchableText).count
        if resetSelection || !results.indices.contains(selectedIndex) {
            selectedIndex = 0
        }
    }

    // MARK: - キー操作

    func toggleTab() {
        tab = tab.other
    }

    func moveSelection(by delta: Int) {
        guard !results.isEmpty else { return }
        selectedIndex = min(max(selectedIndex + delta, 0), results.count - 1)
    }

    /// 選択中の項目を確定する。action を省略すると設定された Enter の動作。
    func confirmSelection(action: ConfirmAction? = nil) {
        guard let entry = selectedEntry else { return }
        confirm(entry, action: action ?? ConfirmAction.current)
    }

    func confirm(_ entry: PanelEntry, action: ConfirmAction) {
        guard entry.isPastable else {
            errorMessage = "ファイルが見つからないため\(action.label)できません"
            return
        }
        onConfirm?(entry, action)
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

    /// 新しいスニペットのフォームを開く。スニペットモードへ切り替える。
    func beginNewSnippet() {
        tab = .snippets
        mode = .form(editing: nil, prefill: nil)
    }

    /// テキストの履歴を初期内容にしてスニペットのフォームを開く。
    func beginSnippet(from entry: PanelEntry) {
        guard let item = entry.historyItem, item.type == .text else { return }
        tab = .snippets
        mode = .form(editing: nil, prefill: item.content)
    }

    func beginEditSelectedSnippet() {
        guard tab == .snippets, case .snippet(let snippet)? = selectedEntry else { return }
        mode = .form(editing: snippet, prefill: nil)
    }

    func beginEdit(_ snippet: Snippet) {
        mode = .form(editing: snippet, prefill: nil)
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
            let saved: Snippet
            if let snippet {
                try snippetStore.update(snippet, title: trimmedTitle, content: content, keyword: keyword)
                saved = snippet
            } else {
                saved = try snippetStore.create(title: trimmedTitle, content: content, keyword: keyword)
            }
            errorMessage = nil
            mode = .list
            reload()
            // 保存したスニペットを選択状態にする
            if let index = results.firstIndex(where: { $0.id == saved.persistentModelID }) {
                selectedIndex = index
            }
        } catch {
            errorMessage = "保存に失敗しました: \(error.localizedDescription)"
        }
    }
}
