import AppKit
import Foundation

/// NSPasteboard.general.changeCount を Timer でポーリングし、テキストを履歴に記録する。
@MainActor
final class ClipboardMonitor {
    private let pasteboard = NSPasteboard.general
    private let store: HistoryStore
    private let interval: TimeInterval
    private var timer: Timer?
    private var lastChangeCount: Int

    /// パスワードマネージャ等が付ける「履歴に残さない」マーカー。
    private static let ignoredTypes: [NSPasteboard.PasteboardType] = [
        .init("org.nspasteboard.ConcealedType"),
        .init("org.nspasteboard.TransientType"),
        .init("com.agilebits.onepassword"),
    ]

    init(store: HistoryStore, interval: TimeInterval = 0.5) {
        self.store = store
        self.interval = interval
        self.lastChangeCount = NSPasteboard.general.changeCount
    }

    func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        let count = pasteboard.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count

        let types = pasteboard.types ?? []
        if types.contains(where: Self.ignoredTypes.contains) { return }

        guard let text = pasteboard.string(forType: .string),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        do {
            try store.record(text)
        } catch {
            NSLog("履歴の保存に失敗: \(error)")
        }
    }
}
