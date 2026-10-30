import Foundation
import SwiftData

/// 「何を・いつ・どのアプリに」貼り付けたかの記録。内容は持たない。
@Model
final class PasteEvent {
    /// 貼り付けた履歴項目またはスニペットの ID（PersistentIdentifier を JSON 化したもの）。
    var targetIDData: Data
    /// 貼り付け先アプリの bundle identifier。
    var targetBundleID: String?
    var pastedAt: Date

    init(targetID: PersistentIdentifier, targetBundleID: String?, pastedAt: Date = .now) {
        self.targetIDData = Self.encode(targetID)
        self.targetBundleID = targetBundleID
        self.pastedAt = pastedAt
    }

    var targetID: PersistentIdentifier? {
        try? JSONDecoder().decode(PersistentIdentifier.self, from: targetIDData)
    }

    /// キー順を固定して、同じ ID が常に同じ Data になるようにする。
    static func encode(_ id: PersistentIdentifier) -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return (try? encoder.encode(id)) ?? Data()
    }
}

/// 項目ごとの使用状況。
struct UsageStats: Equatable {
    var count: Int = 0
    var lastPastedAt: Date?
}

/// パネルの並び順。
enum PanelSortOrder: String, CaseIterable, Identifiable {
    case newest
    case mostUsed
    case recentlyPasted

    static let defaultsKey = "panelSortOrder"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .newest: "新しい順"
        case .mostUsed: "よく使う順"
        case .recentlyPasted: "最近貼り付けた順"
        }
    }

    /// 並び替え。newest は入力順をそのまま返す。
    func sort<T>(_ items: [T], stats: (T) -> UsageStats) -> [T] {
        switch self {
        case .newest:
            return items
        case .mostUsed:
            return items.enumerated().sorted { lhs, rhs in
                let l = stats(lhs.element), r = stats(rhs.element)
                if l.count != r.count { return l.count > r.count }
                if l.lastPastedAt != r.lastPastedAt {
                    return (l.lastPastedAt ?? .distantPast) > (r.lastPastedAt ?? .distantPast)
                }
                return lhs.offset < rhs.offset
            }.map(\.element)
        case .recentlyPasted:
            return items.enumerated().sorted { lhs, rhs in
                let l = stats(lhs.element).lastPastedAt, r = stats(rhs.element).lastPastedAt
                if l != r { return (l ?? .distantPast) > (r ?? .distantPast) }
                return lhs.offset < rhs.offset
            }.map(\.element)
        }
    }
}

@MainActor
final class PasteEventStore {
    static let retentionDaysKey = "pasteEventRetentionDays"
    static let defaultRetentionDays = 90

    static var configuredRetentionDays: Int {
        let value = UserDefaults.standard.integer(forKey: retentionDaysKey)
        return value > 0 ? value : defaultRetentionDays
    }

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    func record(targetID: PersistentIdentifier, targetBundleID: String?, at date: Date = .now) throws -> PasteEvent {
        let event = PasteEvent(targetID: targetID, targetBundleID: targetBundleID, pastedAt: date)
        context.insert(event)
        try context.save()
        return event
    }

    func fetchAll() throws -> [PasteEvent] {
        try context.fetch(FetchDescriptor<PasteEvent>(sortBy: [SortDescriptor(\.pastedAt, order: .reverse)]))
    }

    func count() throws -> Int {
        try context.fetchCount(FetchDescriptor<PasteEvent>())
    }

    /// 項目ごとの回数と最終貼り付け日時。
    ///
    /// キーは `PasteEvent.encode(id)` の Data。JSON から復元した PersistentIdentifier は
    /// 元の ID と `==` で等しくても hashValue が一致せず辞書で引けないため、ID そのものは使わない。
    func usageStats() throws -> [Data: UsageStats] {
        var stats: [Data: UsageStats] = [:]
        for event in try fetchAll() {
            var entry = stats[event.targetIDData, default: UsageStats()]
            entry.count += 1
            if entry.lastPastedAt.map({ event.pastedAt > $0 }) ?? true {
                entry.lastPastedAt = event.pastedAt
            }
            stats[event.targetIDData] = entry
        }
        return stats
    }

    /// 指定した ID の使用状況。
    func usageStats(for id: PersistentIdentifier) throws -> UsageStats {
        try usageStats()[PasteEvent.encode(id)] ?? UsageStats()
    }

    /// 指定した項目のイベントを削除する（項目削除時に呼ぶ）。
    func delete(for targetID: PersistentIdentifier) throws {
        let data = PasteEvent.encode(targetID)
        let descriptor = FetchDescriptor<PasteEvent>(predicate: #Predicate { $0.targetIDData == data })
        for event in try context.fetch(descriptor) {
            context.delete(event)
        }
        try context.save()
    }

    /// 保持期間を過ぎたイベントを削除する。
    func prune(olderThan days: Int, now: Date = .now) throws {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: now) ?? now
        let descriptor = FetchDescriptor<PasteEvent>(predicate: #Predicate { $0.pastedAt < cutoff })
        for event in try context.fetch(descriptor) {
            context.delete(event)
        }
        try context.save()
    }

    /// 対象の履歴項目・スニペットがすでに無いイベントを削除する。
    func pruneOrphans() throws {
        let historyIDs = try context.fetch(FetchDescriptor<ClipboardItem>()).map(\.persistentModelID)
        let snippetIDs = try context.fetch(FetchDescriptor<Snippet>()).map(\.persistentModelID)
        let alive = Set((historyIDs + snippetIDs).map(PasteEvent.encode))
        for event in try fetchAll() where !alive.contains(event.targetIDData) {
            context.delete(event)
        }
        try context.save()
    }

    func deleteAll() throws {
        try context.delete(model: PasteEvent.self)
        try context.save()
    }
}
