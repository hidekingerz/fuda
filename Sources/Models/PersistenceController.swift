import Foundation
import SwiftData

/// SwiftData の ModelContainer を 1 つだけ持つ。
enum PersistenceController {
    static let schema = Schema([ClipboardItem.self, Snippet.self, PasteEvent.self])

    static let shared: ModelContainer = {
        do {
            let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("fuda", isDirectory: true)
            try FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
            let config = ModelConfiguration(url: supportDir.appendingPathComponent("fuda.store"))
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
