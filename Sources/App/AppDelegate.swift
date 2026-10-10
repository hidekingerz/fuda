import AppKit
import KeyboardShortcuts
import SwiftData

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: StatusItemController?
    private var panel: PanelController?
    private var monitor: ClipboardMonitor?
    private var settings: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let context = PersistenceController.shared.mainContext

        let panel = PanelController(context: context)
        self.panel = panel

        let monitor = ClipboardMonitor(store: HistoryStore(context: context))
        monitor.start()
        self.monitor = monitor

        settings = SettingsWindowController()

        statusItem = StatusItemController(
            openPanel: { [weak self] in self?.panel?.show() },
            openSettings: { [weak self] in self?.settings?.show() }
        )

        KeyboardShortcuts.onKeyDown(for: .togglePanel) { [weak self] in
            self?.panel?.toggle()
        }

        // MVP 1: 起動時に Accessibility 権限を確認し、未許可ならシステムのプロンプトを出す
        if !AccessibilityPermission.requestIfNeeded() {
            NSLog("Accessibility 権限が未許可です。貼り付け時に案内します。")
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor?.stop()
    }
}
