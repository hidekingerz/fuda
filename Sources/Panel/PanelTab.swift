import Foundation

/// パネルのモード。履歴とスニペットを別々の一覧で扱う。
enum PanelTab: String, CaseIterable, Identifiable {
    case history
    case snippets

    /// 最後に開いていたモードを覚えておくキー。
    static let defaultsKey = "panelTab"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .history: "履歴"
        case .snippets: "スニペット"
        }
    }

    /// ⇥ で切り替える先。
    var other: PanelTab {
        switch self {
        case .history: .snippets
        case .snippets: .history
        }
    }

    /// 並び順はモードごとに別々に覚える。
    var sortDefaultsKey: String {
        switch self {
        case .history: PanelSortOrder.defaultsKey
        case .snippets: "snippetSortOrder"
        }
    }

    /// このモードで選べる並び順。
    var sortOrders: [PanelSortOrder] {
        switch self {
        case .history: [.newest, .mostUsed, .recentlyPasted]
        case .snippets: [.mostUsed, .title, .newest]
        }
    }

    var defaultSort: PanelSortOrder {
        switch self {
        case .history: .newest
        case .snippets: .mostUsed
        }
    }

    /// 保存された文字列から並び順を決める。このモードで選べない値は既定値にする。
    func resolveSort(_ rawValue: String?) -> PanelSortOrder {
        guard let order = PanelSortOrder(rawValue: rawValue ?? ""), sortOrders.contains(order) else {
            return defaultSort
        }
        return order
    }

    /// 保存された文字列からモードを決める。未設定や不正な値は履歴。
    static func resolve(_ rawValue: String?) -> PanelTab {
        PanelTab(rawValue: rawValue ?? "") ?? .history
    }
}

/// 一覧に出す「3分前」のような経過時間と、日付の短い表記。
enum RelativeTime {
    static func text(for date: Date, now: Date = .now) -> String {
        let seconds = max(0, now.timeIntervalSince(date))
        switch seconds {
        case ..<60: return "今"
        case ..<3600: return "\(Int(seconds / 60))分前"
        case ..<86400: return "\(Int(seconds / 3600))時間前"
        case ..<(86400 * 7): return "\(Int(seconds / 86400))日前"
        default: return shortDate(date)
        }
    }

    static func shortDate(_ date: Date) -> String {
        formatter.string(from: date)
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日"
        return formatter
    }()
}
