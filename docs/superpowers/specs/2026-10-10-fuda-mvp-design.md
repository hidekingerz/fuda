# fuda MVP 設計メモ（2026-10-10）

## 目的
macOS 向けのクリップボード履歴＋スニペット管理アプリ。
グローバルショートカットでパネルを呼び出し、履歴またはスニペットを選んで
呼び出し元アプリへ貼り付ける。

## 技術方針（ユーザー指定）
- Swift / AppKit 骨格 + SwiftUI パネル UI。Electron/Tauri/WebView は不使用
- メニューバー常駐（LSUIElement = YES）
- パネルは `NSPanel(.nonactivatingPanel)`。呼び出し元のフォーカスを奪わない
- クリップボード監視は `NSPasteboard.general.changeCount` を 0.5 秒 Timer でポーリング
- 永続化は SwiftData（`ClipboardItem` と `Snippet` は別モデル）
- グローバルショートカットは sindresorhus/KeyboardShortcuts（SwiftPM）
- 貼り付けは「選択 → パネルを閉じる → 元アプリへ Cmd+V を CGEvent 送信」
- 最低対応 OS は macOS 14（SwiftData の要件）

## モジュール構成
| ディレクトリ | 役割 |
|---|---|
| `Sources/App` | `AppDelegate`、`StatusItemController`（メニューバー）、ショートカット定義 |
| `Sources/Models` | `ClipboardItem`、`Snippet`、`PersistenceController`、`HistoryStore`（上限プルーニング） |
| `Sources/Clipboard` | `ClipboardMonitor`（ポーリング）、`PasteService`（CGEvent 送信） |
| `Sources/Permissions` | `AccessibilityPermission`（確認・システム設定への誘導） |
| `Sources/Panel` | `PanelController`（NSPanel + キー監視）、`PanelViewModel`、`PanelView`、`SnippetFormView` |
| `Sources/Settings` | `SettingsWindowController`、`SettingsView` |
| `Tests` | `HistoryStore` のプルーニング、検索フィルタのユニットテスト |

## データモデル
- `ClipboardItem`: `content: String`, `type: ClipboardItemType(text/image/file)`, `createdAt: Date`, `pinned: Bool`
- `Snippet`: `title`, `content`, `keyword: String?`, `createdAt`, `updatedAt`
- 履歴上限は既定 200（`UserDefaults` の `historyLimit`）。pinned は削除対象外
- 同一内容を再コピーした場合は重複追加せず `createdAt` を更新して先頭へ移動

## データフロー
1. `ClipboardMonitor` が changeCount の変化を検知 → 文字列を `HistoryStore.record` へ
2. `HistoryStore` が重複判定・挿入・プルーニングを行い `historyDidChange` を通知
3. `PanelController.toggle()` が呼ばれると `PanelViewModel.reload()` でデータを再取得し表示
4. ↑↓ / Enter / Esc は `NSEvent.addLocalMonitorForEvents` でパネル表示中だけ横取り
5. Enter → 選択項目の内容を `NSPasteboard` に書き込み → パネルを閉じる → 元アプリを前面化 → `PasteService.sendCommandV()`

## キーボード操作
- 検索欄に常にフォーカス。↑↓で選択、Enter で貼り付け、Esc で閉じる
- Cmd+N: スニペット新規作成フォーム、Cmd+E: 選択中スニペットを編集
- フォーム中の Esc は一覧へ戻る

## MVP スコープ外（後回し）
画像・ファイル履歴、キーワード展開、プレースホルダー、iCloud 同期、設定画面の作り込み、署名・公証。
