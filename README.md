# fuda

macOS 用のクリップボード履歴＋スニペット管理アプリ。
ショートカットでパネルを呼び出し、履歴または登録済みスニペットを選んで元のアプリに貼り付ける。

## 必要なもの

- macOS 14 以降
- Xcode 16 以降
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)（`brew install xcodegen`）

## ビルドと実行

```sh
xcodegen generate            # fuda.xcodeproj を生成（project.yml が正）
open fuda.xcodeproj          # Xcode で開いて ⌘R
```

コマンドラインの場合:

```sh
xcodebuild build -project fuda.xcodeproj -scheme fuda -configuration Debug -derivedDataPath build/DerivedData
open build/DerivedData/Build/Products/Debug/fuda.app
```

テスト:

```sh
xcodebuild test -project fuda.xcodeproj -scheme fuda -destination 'platform=macOS' -derivedDataPath build/DerivedData
```

## 使い方

| 操作 | キー |
|---|---|
| パネルを開く／閉じる | ⌘⇧V（設定で変更可） |
| 項目を選ぶ | ↑ / ↓（または ^P / ^N） |
| 貼り付け | ⏎ |
| 閉じる | esc |
| スニペットを追加 | ⌘N またはパネル右上の「+」 |
| 選択中のスニペットを編集 | ⌘E または右クリック |
| 履歴のピン留め・削除 | 右クリック |

初回起動時にアクセシビリティ権限のダイアログが出ます。貼り付け（元アプリへの ⌘V 送信）に必要なので、
システム設定 > プライバシーとセキュリティ > アクセシビリティ で fuda を許可してください。
クリップボード履歴の取得自体は権限がなくても動きます。

## 構成

- `project.yml` — XcodeGen のプロジェクト定義
- `Sources/App` — エントリポイント、メニューバー、グローバルショートカット
- `Sources/Models` — SwiftData モデル（`ClipboardItem` / `Snippet`）とストア
- `Sources/Clipboard` — クリップボード監視と貼り付け
- `Sources/Panel` — NSPanel と SwiftUI のパネル UI
- `Sources/Settings` — 設定ウィンドウ
- `Tests` — ユニットテスト
- `docs/superpowers/specs` — 設計メモ

データは `~/Library/Application Support/fuda/fuda.store` に保存されます。
