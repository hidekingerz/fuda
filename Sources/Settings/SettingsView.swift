import KeyboardShortcuts
import SwiftUI

struct SettingsView: View {
    @AppStorage(HistoryStore.limitKey) private var historyLimit: Int = HistoryStore.defaultLimit
    @State private var accessibilityTrusted = AccessibilityPermission.isTrusted

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
                Text("ピン留めした項目は上限の対象外です。")
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
    }
}
