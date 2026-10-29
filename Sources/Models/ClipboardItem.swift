import Foundation
import SwiftData

enum ClipboardItemType: String, Codable {
    case text
    case image
    case file
}

@Model
final class ClipboardItem {
    var content: String
    var typeRawValue: String
    var createdAt: Date
    var pinned: Bool

    var type: ClipboardItemType {
        get { ClipboardItemType(rawValue: typeRawValue) ?? .text }
        set { typeRawValue = newValue.rawValue }
    }

    /// type == .file のとき、content を改行区切りのパスとして解釈した URL 一覧。
    var fileURLs: [URL] {
        guard type == .file else { return [] }
        return Self.filePaths(from: content).map { URL(fileURLWithPath: $0) }
    }

    /// type == .file で、いずれかのファイルが存在しなければ true。
    var hasMissingFile: Bool {
        fileURLs.contains { !FileManager.default.fileExists(atPath: $0.path) }
    }

    static func fileContent(paths: [String]) -> String {
        paths.joined(separator: "\n")
    }

    static func filePaths(from content: String) -> [String] {
        content.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
    }

    init(content: String, type: ClipboardItemType = .text, createdAt: Date = .now, pinned: Bool = false) {
        self.content = content
        self.typeRawValue = type.rawValue
        self.createdAt = createdAt
        self.pinned = pinned
    }
}
