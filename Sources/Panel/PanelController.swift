import AppKit
import SwiftData
import SwiftUI

/// 呼び出し元アプリのフォーカスを奪わない NSPanel に SwiftUI ビューをホストする。
@MainActor
final class PanelController {
    private let panel: NSPanel
    private let viewModel: PanelViewModel
    private var keyMonitor: Any?
    private var previousApp: NSRunningApplication?

    init(context: ModelContext) {
        viewModel = PanelViewModel(context: context)

        panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 420),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView, .closable],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.contentView = NSHostingView(rootView: PanelView(viewModel: viewModel))

        viewModel.onConfirm = { [weak self] entry, action in self?.confirm(entry, action: action) }
        viewModel.onDismiss = { [weak self] in self?.hide() }

        NotificationCenter.default.addObserver(
            forName: .historyDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.panel.isVisible else { return }
                self.viewModel.reload()
            }
        }
        NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification, object: panel, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.hide() }
        }
    }

    var isVisible: Bool { panel.isVisible }

    func toggle() {
        if panel.isVisible { hide() } else { show() }
    }

    /// query を渡すと検索欄にその文字列を入れた状態で開く。
    func show(query: String? = nil) {
        previousApp = NSWorkspace.shared.frontmostApplication
        viewModel.resetForShow()
        if let query, !query.isEmpty {
            viewModel.query = query
        }
        panel.setContentSize(PanelTextSize.panelSize(for: .current))
        positionPanel()
        panel.makeKeyAndOrderFront(nil)
        installKeyMonitor()
    }

    func hide() {
        removeKeyMonitor()
        panel.orderOut(nil)
    }

    // MARK: - 確定

    /// コピーのみならペーストボードに書いて閉じる。貼り付けなら Cmd+V を送り、送れたときだけ記録する。
    private func confirm(_ entry: PanelEntry, action: ConfirmAction) {
        let target = previousApp
        hide()
        switch action {
        case .copyOnly:
            PasteService.copyToPasteboard(entry)
        case .paste:
            if PasteService.paste(entry, into: target) {
                viewModel.recordPaste(of: entry, to: target?.bundleIdentifier)
            }
        }
    }

    // MARK: - 配置

    private func positionPanel() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let frame = screen?.visibleFrame else { return }
        let size = panel.frame.size
        let origin = NSPoint(
            x: frame.midX - size.width / 2,
            y: frame.midY - size.height / 2 + frame.height * 0.1
        )
        panel.setFrameOrigin(origin)
    }

    // MARK: - キー操作

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel.isVisible, event.window === self.panel else { return event }
            return self.handle(event) ? nil : event
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    /// 処理したら true（イベントを飲み込む）。
    private func handle(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if case .form = viewModel.mode {
            if event.keyCode == 53 { // esc
                viewModel.cancelForm()
                return true
            }
            return false
        }

        switch event.keyCode {
        case 53: // esc
            viewModel.dismiss()
            return true
        case 126: // ↑
            viewModel.moveSelection(by: -1)
            return true
        case 125: // ↓
            viewModel.moveSelection(by: 1)
            return true
        case 36, 76: // return / enter（⇧ でもう一方の動作）
            viewModel.confirmSelection(
                action: ConfirmAction.action(enterAction: .current, shift: flags.contains(.shift))
            )
            return true
        default:
            break
        }

        if flags == .command, let chars = event.charactersIgnoringModifiers {
            switch chars {
            case "n":
                viewModel.beginNewSnippet()
                return true
            case "e":
                viewModel.beginEditSelectedSnippet()
                return true
            default:
                break
            }
        }
        if flags == .control, let chars = event.charactersIgnoringModifiers {
            switch chars {
            case "p": viewModel.moveSelection(by: -1); return true
            case "n": viewModel.moveSelection(by: 1); return true
            default: break
            }
        }
        return false
    }
}

/// nonactivatingPanel でもキーウィンドウになれるようにする。
private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
