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

    init(content: String, type: ClipboardItemType = .text, createdAt: Date = .now, pinned: Bool = false) {
        self.content = content
        self.typeRawValue = type.rawValue
        self.createdAt = createdAt
        self.pinned = pinned
    }
}
