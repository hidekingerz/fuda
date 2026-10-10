import Foundation
import SwiftData

@Model
final class Snippet {
    var title: String
    var content: String
    var keyword: String?
    var createdAt: Date
    var updatedAt: Date

    init(title: String, content: String, keyword: String? = nil, createdAt: Date = .now) {
        self.title = title
        self.content = content
        self.keyword = keyword
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }
}
