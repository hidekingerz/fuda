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

    /// 対象アプリを前面にしてから貼り付ける。
    @MainActor
    static func paste(_ content: String, into app: NSRunningApplication?) {
        copyToPasteboard(content)
        guard AccessibilityPermission.isTrusted else {
            AccessibilityPermission.showGuideAlert()
            return
        }
        if let app, !app.isActive {
            app.activate()
        }
        // 前面化と「パネルが閉じた」イベントの処理を待ってから送る
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            sendCommandV()
        }
    }
}
