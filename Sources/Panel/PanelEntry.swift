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
        case .history(let item):
            switch item.type {
            case .file: item.fileURLs.map(\.lastPathComponent).joined(separator: ", ")
            case .image: item.imageTitle
            case .text: item.content.firstLine
            }
        case .snippet(let snippet):
            snippet.title
        }
    }

    /// 一覧の 2 行目（ファイルなら親ディレクトリ、スニペットなら内容の先頭行）。
    var subtitle: String? {
        switch self {
        case .history(let item):
            switch item.type {
            case .file:
                return item.fileURLs.first?.deletingLastPathComponent().path
            case .image:
                return item.imageData.map { "PNG · \(ImageProcessing.sizeText(bytes: $0.count))" }
            case .text:
                return nil
            }
        case .snippet(let snippet):
            return snippet.content.firstLine
        }
    }

    var historyItem: ClipboardItem? {
        if case .history(let item) = self { return item }
        return nil
    }

    var isFile: Bool { historyItem?.type == .file }
    var isImage: Bool { historyItem?.type == .image }

    /// ファイル項目で実体が消えている場合は貼り付けできない。
    var isPastable: Bool {
        guard let item = historyItem, item.type == .file else { return true }
        return !item.hasMissingFile
    }

    /// スニペットのキーワード。履歴には無い。
    var keyword: String? {
        if case .snippet(let snippet) = self { return snippet.keyword }
        return nil
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
            item.type == .image ? item.imageTitle : item.content
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

    /// query がキーワードと完全一致（前後空白無視・大文字小文字無視）するか。
    static func matchesKeyword(_ keyword: String?, query: String) -> Bool {
        guard let keyword, !keyword.isEmpty else { return false }
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else { return false }
        return keyword.compare(normalizedQuery, options: [.caseInsensitive]) == .orderedSame
    }

    /// filter した上で、キーワード完全一致の項目を順序を保ったまま先頭へ移動する。
    static func rank<T>(_ items: [T], query: String, text: (T) -> String, keyword: (T) -> String?) -> [T] {
        let filtered = filter(items, query: query, text: text)
        let exact = filtered.filter { matchesKeyword(keyword($0), query: query) }
        guard !exact.isEmpty else { return filtered }
        let rest = filtered.filter { !matchesKeyword(keyword($0), query: query) }
        return exact + rest
    }
}

extension String {
    var firstLine: String {
        let line = split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: true).first.map(String.init) ?? self
        return line.trimmingCharacters(in: .whitespaces)
    }
}
