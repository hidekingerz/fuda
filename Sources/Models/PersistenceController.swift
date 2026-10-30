import Foundation
import SwiftData

/// SwiftData の ModelContainer を 1 つだけ持つ。
enum PersistenceController {
    static let schema = Schema([ClipboardItem.self, Snippet.self, PasteEvent.self])

    /// 環境変数 FUDA_STORE_PATH で保存先を差し替えられる（デモ用データやデバッグに使う）。
    static var storeURL: URL {
        if let override = ProcessInfo.processInfo.environment["FUDA_STORE_PATH"], !override.isEmpty {
            return URL(fileURLWithPath: override)
        }
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("fuda", isDirectory: true)
        return supportDir.appendingPathComponent("fuda.store")
    }

    static let shared: ModelContainer = {
        do {
            let url = storeURL
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let config = ModelConfiguration(url: url)
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("ModelContainer の作成に失敗: \(error)")
        }
    }()

    /// テスト用のインメモリコンテナ。
    static func inMemory() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }
}
