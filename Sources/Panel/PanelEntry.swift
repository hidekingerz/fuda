import Foundation
import SwiftData

/// パネルに並ぶ 1 行。履歴とスニペットを横断して扱う。
enum PanelEntry: Identifiable, Hashable {
    case history(ClipboardItem)
    case snippet(Snippet)

    var id: PersistentIdentifier {
        switch self {
        case .history(let item): item.persistentModelID
        case .snippet(let snippet): snippet.persistentModelID
        }
    }

    var content: String {
        switch self {
        case .history(let item): item.content
        case .snippet(let snippet): snippet.content
        }
    }

    /// 一覧に表示する見出し。
    var title: String {
        switch self {
        case .history(let item): item.content.firstLine
        case .snippet(let snippet): snippet.title
        }
    }

    var isSnippet: Bool {
        if case .snippet = self { return true }
        return false
    }

    var isPinned: Bool {
        if case .history(let item) = self { return item.pinned }
        return false
    }

    /// 検索対象のテキスト。
    var searchableText: String {
        switch self {
        case .history(let item):
            item.content
        case .snippet(let snippet):
            [snippet.title, snippet.keyword ?? "", snippet.content].joined(separator: "\n")
        }
    }
}

/// 検索文字列（空白区切りの AND 検索、大文字小文字無視）でフィルタする。
enum PanelSearch {
    static func filter<T>(_ items: [T], query: String, text: (T) -> String) -> [T] {
        let terms = query
            .split(whereSeparator: \.isWhitespace)
            .map { $0.lowercased() }
        guard !terms.isEmpty else { return items }
        return items.filter { item in
            let haystack = text(item).lowercased()
            return terms.allSatisfy { haystack.contains($0) }
        }
    }
}

extension String {
    var firstLine: String {
        let line = split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: true).first.map(String.init) ?? self
        return line.trimmingCharacters(in: .whitespaces)
    }
}
