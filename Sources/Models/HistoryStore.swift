import Foundation
import SwiftData

extension Notification.Name {
    static let historyDidChange = Notification.Name("fuda.historyDidChange")
}

/// クリップボード履歴の追加・重複排除・上限プルーニングを担当する。
@MainActor
final class HistoryStore {
    static let defaultLimit = 200
    static let limitKey = "historyLimit"

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    static var configuredLimit: Int {
        let value = UserDefaults.standard.integer(forKey: limitKey)
        return value > 0 ? value : defaultLimit
    }

    /// 新しいテキストを履歴に記録する。既存の同一内容は先頭へ移動する。
    @discardableResult
    func record(_ content: String, type: ClipboardItemType = .text, at date: Date = .now, limit: Int? = nil) throws -> ClipboardItem {
        let item: ClipboardItem
        if let existing = try fetchExisting(content: content, type: type) {
            existing.createdAt = date
            item = existing
        } else {
            item = ClipboardItem(content: content, type: type, createdAt: date)
            context.insert(item)
        }
        try prune(limit: limit ?? Self.configuredLimit)
        try context.save()
        NotificationCenter.default.post(name: .historyDidChange, object: nil)
        return item
    }

    /// pinned でない項目が limit を超えていれば古いものから削除する。
    func prune(limit: Int) throws {
        let descriptor = FetchDescriptor<ClipboardItem>(
            predicate: #Predicate { !$0.pinned },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let unpinned = try context.fetch(descriptor)
        for item in unpinned.dropFirst(max(limit, 0)) {
            context.delete(item)
        }
    }

    func delete(_ item: ClipboardItem) throws {
        context.delete(item)
        try context.save()
        NotificationCenter.default.post(name: .historyDidChange, object: nil)
    }

    func togglePinned(_ item: ClipboardItem) throws {
        item.pinned.toggle()
        try context.save()
        NotificationCenter.default.post(name: .historyDidChange, object: nil)
    }

    func fetchAll() throws -> [ClipboardItem] {
        let descriptor = FetchDescriptor<ClipboardItem>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    private func fetchExisting(content: String, type: ClipboardItemType) throws -> ClipboardItem? {
        let typeRawValue = type.rawValue
        var descriptor = FetchDescriptor<ClipboardItem>(
            predicate: #Predicate { $0.content == content && $0.typeRawValue == typeRawValue }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
