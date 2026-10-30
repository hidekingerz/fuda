import KeyboardShortcuts
import SwiftData
import SwiftUI

struct SettingsView: View {
    @AppStorage(HistoryStore.limitKey) private var historyLimit: Int = HistoryStore.defaultLimit
    @AppStorage(HistoryStore.imageLimitKey) private var imageLimit: Int = HistoryStore.defaultImageLimit
    @AppStorage(HistoryStore.imageMaxBytesKey) private var imageMaxBytes: Int = HistoryStore.defaultImageMaxBytes
    @AppStorage(PasteEventStore.retentionDaysKey) private var retentionDays: Int = PasteEventStore.defaultRetentionDays
    @State private var accessibilityTrusted = AccessibilityPermission.isTrusted
    @State private var pasteEventCount = 0
    @State private var confirmClear = false

    private let pasteEvents = PasteEventStore(context: PersistenceController.shared.mainContext)

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Form {
            Section("ショートカット") {
                KeyboardShortcuts.Recorder("パネルを開く:", name: .togglePanel)
            }
            Section("履歴") {
                Stepper(value: $historyLimit, in: 10...2000, step: 10) {
                    HStack {
                        Text("保存件数の上限")
                        Spacer()
                        Text("\(historyLimit) 件").foregroundStyle(.secondary)
                    }
                }
                Stepper(value: $imageLimit, in: 5...500, step: 5) {
                    HStack {
                        Text("画像の保存件数の上限")
                        Spacer()
                        Text("\(imageLimit) 件").foregroundStyle(.secondary)
                    }
                }
                Stepper(value: $imageMaxBytes, in: 1_048_576...209_715_200, step: 1_048_576) {
                    HStack {
                        Text("保存する画像の最大サイズ")
                        Spacer()
                        Text(ImageProcessing.sizeText(bytes: imageMaxBytes)).foregroundStyle(.secondary)
                    }
                }
                Text("ピン留めした項目は上限の対象外です。最大サイズを超える画像は保存しません。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("貼り付けの記録") {
                Stepper(value: $retentionDays, in: 1...365, step: 1) {
                    HStack {
                        Text("保持期間")
                        Spacer()
                        Text("\(retentionDays) 日").foregroundStyle(.secondary)
                    }
                }
                HStack {
                    Text("記録件数")
                    Spacer()
                    Text("\(pasteEventCount) 件").foregroundStyle(.secondary)
                    Button("消去…") { confirmClear = true }
                        .disabled(pasteEventCount == 0)
                }
                Text("何を・いつ・どのアプリに貼り付けたかを記録し、「よく使う順」などの並び替えに使います。内容そのものは記録しません。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("権限") {
                HStack {
                    Image(systemName: accessibilityTrusted ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(accessibilityTrusted ? .green : .red)
                    Text(accessibilityTrusted ? "アクセシビリティ: 許可済み" : "アクセシビリティ: 未許可")
                    Spacer()
                    if !accessibilityTrusted {
                        Button("システム設定を開く") { AccessibilityPermission.openSystemSettings() }
                    }
                }
                Text("貼り付け（Cmd+V の送信）に必要です。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .onReceive(timer) { _ in
            accessibilityTrusted = AccessibilityPermission.isTrusted
        }
        .onAppear { refreshPasteEventCount() }
        .confirmationDialog("貼り付けの記録をすべて消去しますか？", isPresented: $confirmClear) {
            Button("消去", role: .destructive) {
                try? pasteEvents.deleteAll()
                refreshPasteEventCount()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("「よく使う順」の並びがリセットされます。この操作は取り消せません。")
        }
    }

    private func refreshPasteEventCount() {
        pasteEventCount = (try? pasteEvents.count()) ?? 0
    }
}
