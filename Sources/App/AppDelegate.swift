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

        // 保持期間を過ぎた／対象が消えた貼り付けイベントを掃除する
        let pasteEvents = PasteEventStore(context: context)
        do {
            try pasteEvents.prune(olderThan: PasteEventStore.configuredRetentionDays)
            try pasteEvents.pruneOrphans()
        } catch {
            NSLog("貼り付けイベントの掃除に失敗: \(error)")
        }

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
        KeyboardShortcuts.onKeyDown(for: .toggleSnippets) { [weak self] in
            self?.panel?.toggle(tab: .snippets)
        }

        // MVP 1: 起動時に Accessibility 権限を確認し、未許可ならシステムのプロンプトを出す
        if !AccessibilityPermission.requestIfNeeded() {
            NSLog("Accessibility 権限が未許可です。貼り付け時に案内します。")
        }
    }

    /// `fuda://panel` でパネルを開く。`?q=検索語` で検索欄を埋め、`?mode=history|snippets` でモードを選ぶ。
    /// Raycast や Alfred、シェルからの呼び出し用。
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "fuda" {
            switch url.host {
            case "panel":
                let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
                let query = items.first { $0.name == "q" }?.value
                let tab = items.first { $0.name == "mode" }?.value.flatMap(PanelTab.init(rawValue:))
                panel?.show(query: query, tab: tab)
            case "settings": settings?.show()
            default: NSLog("未対応の URL: \(url)")
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor?.stop()
    }
}
