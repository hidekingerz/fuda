import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// パネルの表示／非表示。既定は ⌘⇧V。
    static let togglePanel = Self("togglePanel", default: .init(.v, modifiers: [.command, .shift]))
    /// スニペットモードでパネルを開く。⌘⇧S などは他のアプリと衝突しやすいので既定では割り当てない。
    static let toggleSnippets = Self("toggleSnippets")
}
