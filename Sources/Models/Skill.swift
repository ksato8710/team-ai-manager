import Foundation
import GRDB

enum SkillCategory: String, Codable, CaseIterable, DatabaseValueConvertible {
    case design, tech, business, research

    var displayName: String { rawValue.capitalized }

    var color: String {
        switch self {
        case .design: return "purple"
        case .tech: return "blue"
        case .business: return "green"
        case .research: return "orange"
        }
    }
}

struct Skill: Identifiable, Codable, Hashable {
    var id: Int64?
    var name: String
    var category: SkillCategory
    var description: String?
    var createdAt: String?
    var updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, category, description
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

extension Skill: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "skills"

    enum Columns: String, ColumnExpression {
        case id, name, category, description
        case createdAt = "created_at", updatedAt = "updated_at"
    }

    func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["name"] = name
        container["category"] = category
        container["description"] = description
        if let createdAt { container["created_at"] = createdAt }
        if let updatedAt { container["updated_at"] = updatedAt }
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }

    static let memberSkills = hasMany(MemberSkill.self)
}
