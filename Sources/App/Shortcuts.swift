import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// パネルの表示／非表示。既定は ⌘⇧V。
    static let togglePanel = Self("togglePanel", default: .init(.v, modifiers: [.command, .shift]))
}
