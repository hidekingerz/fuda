import Foundation
import SwiftData

/// スニペットの CRUD。
@MainActor
final class SnippetStore {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchAll() throws -> [Snippet] {
        let descriptor = FetchDescriptor<Snippet>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    @discardableResult
    func create(title: String, content: String, keyword: String?) throws -> Snippet {
        let snippet = Snippet(title: title, content: content, keyword: Self.normalized(keyword))
        context.insert(snippet)
        try context.save()
        return snippet
    }

    func update(_ snippet: Snippet, title: String, content: String, keyword: String?) throws {
        snippet.title = title
        snippet.content = content
        snippet.keyword = Self.normalized(keyword)
        snippet.updatedAt = .now
        try context.save()
    }

    func delete(_ snippet: Snippet) throws {
        context.delete(snippet)
        try context.save()
    }

    private static func normalized(_ keyword: String?) -> String? {
        guard let keyword else { return nil }
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
