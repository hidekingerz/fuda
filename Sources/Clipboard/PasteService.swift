import AppKit
import Carbon.HIToolbox

/// 内容をペーストボードへ書き込み、前面アプリへ Cmd+V を送る。
enum PasteService {
    /// ペーストボードに書き込む。履歴の重複排除は HistoryStore 側で行われる。
    static func copyToPasteboard(_ content: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(content, forType: .string)
    }

    /// ファイル URL を書き込む。Finder には file-url、テキスト欄にはパスとして貼り付く。
    static func copyToPasteboard(fileURLs: [URL]) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(fileURLs as [NSURL])
        pasteboard.setString(fileURLs.map(\.path).joined(separator: "\n"), forType: .string)
    }

    /// 画像を PNG と TIFF の両方で書き込む（TIFF しか受け付けないアプリ向け）。
    static func copyToPasteboard(imageData: Data) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(imageData, forType: .png)
        if let tiff = NSImage(data: imageData)?.tiffRepresentation {
            pasteboard.setData(tiff, forType: .tiff)
        }
    }

    /// パネルの項目をペーストボードへ書き込む。
    static func copyToPasteboard(_ entry: PanelEntry) {
        switch entry.historyItem?.type {
        case .file?:
            copyToPasteboard(fileURLs: entry.historyItem?.fileURLs ?? [])
        case .image?:
            if let data = entry.historyItem?.imageData {
                copyToPasteboard(imageData: data)
            }
        default:
            copyToPasteboard(entry.content)
        }
    }

    /// Cmd+V を CGEvent で送信する。Accessibility 権限が必要。
    static func sendCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyCode = CGKeyCode(kVK_ANSI_V)
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else { return }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cgSessionEventTap)
        keyUp.post(tap: .cgSessionEventTap)
    }

    /// 対象アプリを前面にしてから貼り付ける。Cmd+V を送れた場合に true。
    @MainActor
    @discardableResult
    static func paste(_ entry: PanelEntry, into app: NSRunningApplication?) -> Bool {
        copyToPasteboard(entry)
        guard AccessibilityPermission.isTrusted else {
            AccessibilityPermission.showGuideAlert()
            return false
        }
        if let app, !app.isActive {
            app.activate()
        }
        // 前面化と「パネルが閉じた」イベントの処理を待ってから送る
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            sendCommandV()
        }
        return true
    }
}
