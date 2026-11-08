import AppKit

/// メニューバーの NSStatusItem。
@MainActor
final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let openPanel: () -> Void
    private let openSettings: () -> Void

    init(openPanel: @escaping () -> Void, openSettings: @escaping () -> Void) {
        self.openPanel = openPanel
        self.openSettings = openSettings
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(named: "MenuBarIcon")
            button.image?.isTemplate = true
            button.image?.accessibilityDescription = "fuda"
        }
        statusItem.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let open = NSMenuItem(title: "パネルを開く", action: #selector(openPanelAction), keyEquivalent: "")
        open.target = self
        menu.addItem(open)

        menu.addItem(.separator())

        let accessibility = NSMenuItem(title: "アクセシビリティ権限…", action: #selector(openAccessibilityAction), keyEquivalent: "")
        accessibility.target = self
        menu.addItem(accessibility)

        let settings = NSMenuItem(title: "設定…", action: #selector(openSettingsAction), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "fuda を終了", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        menu.delegate = self
        return menu
    }

    @objc private func openPanelAction() { openPanel() }
    @objc private func openSettingsAction() { openSettings() }
    @objc private func openAccessibilityAction() { AccessibilityPermission.openSystemSettings() }
}

extension StatusItemController: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        guard let item = menu.items.first(where: { $0.action == #selector(openAccessibilityAction) }) else { return }
        item.title = AccessibilityPermission.isTrusted
            ? "アクセシビリティ権限: 許可済み"
            : "アクセシビリティ権限を許可…"
    }
}
