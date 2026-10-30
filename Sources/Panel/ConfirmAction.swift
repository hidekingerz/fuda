import Foundation

/// パネルで項目を確定したときの動作。
enum ConfirmAction: String, CaseIterable, Identifiable {
    /// ペーストボードに書き込み、元のアプリへ Cmd+V を送る。
    case paste
    /// ペーストボードに書き込むだけ。Cmd+V は送らない。
    case copyOnly

    static let defaultsKey = "enterAction"
    /// 安全側に倒し、既定では Cmd+V を送らない。
    static let `default`: ConfirmAction = .copyOnly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .paste: "貼り付け"
        case .copyOnly: "コピーのみ"
        }
    }

    /// キー案内に出す短い名前。
    var shortLabel: String {
        switch self {
        case .paste: "貼り付け"
        case .copyOnly: "コピー"
        }
    }

    /// もう一方の動作。⇧⏎ に割り当てる。
    var alternate: ConfirmAction {
        switch self {
        case .paste: .copyOnly
        case .copyOnly: .paste
        }
    }

    /// 設定されている Enter の動作。
    static var current: ConfirmAction {
        resolve(UserDefaults.standard.string(forKey: defaultsKey))
    }

    /// 保存された文字列から動作を決める。未設定や不正な値は既定値。
    static func resolve(_ rawValue: String?) -> ConfirmAction {
        ConfirmAction(rawValue: rawValue ?? "") ?? .default
    }

    /// Enter（shift なし）または ⇧⏎（shift あり）で実行する動作。
    static func action(enterAction: ConfirmAction, shift: Bool) -> ConfirmAction {
        shift ? enterAction.alternate : enterAction
    }
}
