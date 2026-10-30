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

        do {
            if let fileContent = Self.fileContent(from: pasteboard) {
                try store.record(fileContent, type: .file)
            } else if let text = pasteboard.string(forType: .string),
                      !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                try store.record(text, type: .text)
            } else if let payload = Self.imagePayload(from: pasteboard) {
                try store.recordImage(payload)
            }
        } catch {
            NSLog("履歴の保存に失敗: \(error)")
        }
    }

    /// スクリーンショットなどの画像を PNG に正規化する。上限サイズを超えるものは nil。
    static func imagePayload(from pasteboard: NSPasteboard) -> ImagePayload? {
        let data = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff)
        guard let data else { return nil }
        return ImageProcessing.payload(from: data, maxBytes: HistoryStore.configuredImageMaxBytes)
    }

    /// Finder などでコピーされたファイル URL を、改行区切りのパス文字列にする。
    static func fileContent(from pasteboard: NSPasteboard) -> String? {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL],
              !urls.isEmpty else { return nil }
        return ClipboardItem.fileContent(paths: urls.map(\.path))
    }
}
