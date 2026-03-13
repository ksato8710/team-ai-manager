import Foundation
import GRDB

enum KnowledgeCategory: String, Codable, CaseIterable, DatabaseValueConvertible {
    case caseStudy = "case_study"
    case process
    case guideline
    case template
    case researchFinding = "research_finding"
    case principle
    case tutorial

    var displayName: String {
        switch self {
        case .caseStudy: return "Case Study"
        case .process: return "Process"
        case .guideline: return "Guideline"
        case .template: return "Template"
        case .researchFinding: return "Research Finding"
        case .principle: return "Principle"
        case .tutorial: return "Tutorial"
        }
    }
}

struct Knowledge: Identifiable, Codable, Hashable {
    var id: Int64?
    var title: String
    var content: String
    var category: KnowledgeCategory
    var tags: String? // JSON array
    var authorId: Int64?
    var projectId: Int64?
    var isPublished: Bool
    var createdAt: String?
    var updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, title, content, category, tags
        case authorId = "author_id"
        case projectId = "project_id"
        case isPublished = "is_published"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var tagList: [String] {
        guard let data = tags?.data(using: .utf8),
              let array = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return array
    }
}

extension Knowledge: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "knowledge"

    enum Columns: String, ColumnExpression {
        case id, title, content, category, tags
        case authorId = "author_id", projectId = "project_id"
        case isPublished = "is_published"
        case createdAt = "created_at", updatedAt = "updated_at"
    }

    func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["title"] = title
        container["content"] = content
        container["category"] = category
        container["tags"] = tags
        container["author_id"] = authorId
        container["project_id"] = projectId
        container["is_published"] = isPublished
        if let createdAt { container["created_at"] = createdAt }
        if let updatedAt { container["updated_at"] = updatedAt }
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }

    static let author = belongsTo(Member.self, using: ForeignKey(["author_id"]))
    static let project = belongsTo(Project.self, using: ForeignKey(["project_id"]))
}
