import SwiftUI

/// パネルの文字サイズ。倍率でフォントとレイアウトをまとめて拡大する。
enum PanelTextSize: String, CaseIterable, Identifiable {
    case standard
    case large
    case extraLarge

    static let defaultsKey = "panelTextSize"
    static let baseWidth: CGFloat = 520
    static let baseHeight: CGFloat = 420

    var id: String { rawValue }

    var label: String {
        switch self {
        case .standard: "標準"
        case .large: "大"
        case .extraLarge: "特大"
        }
    }

    var scale: CGFloat {
        switch self {
        case .standard: 1.0
        case .large: 1.2
        case .extraLarge: 1.4
        }
    }

    static var current: PanelTextSize {
        PanelTextSize(rawValue: UserDefaults.standard.string(forKey: defaultsKey) ?? "") ?? .large
    }

    /// 倍率を反映したパネルの大きさ。
    static func panelSize(for size: PanelTextSize) -> CGSize {
        CGSize(width: baseWidth * size.scale, height: baseHeight * size.scale)
    }
}

private struct PanelTextScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1.0
}

extension EnvironmentValues {
    var panelTextScale: CGFloat {
        get { self[PanelTextScaleKey.self] }
        set { self[PanelTextScaleKey.self] = newValue }
    }
}
