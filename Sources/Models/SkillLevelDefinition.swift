import Foundation
import GRDB

struct SkillLevelDefinition: Identifiable, Codable, Hashable {
    var id: Int64?
    var skillId: Int64
    var level: Int // 1-5
    var title: String
    var levelDescription: String

    enum CodingKeys: String, CodingKey {
        case id
        case skillId = "skill_id"
        case level
        case title
        case levelDescription = "level_description"
    }
}

extension SkillLevelDefinition: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "skill_level_definitions"

    enum Columns: String, ColumnExpression {
        case id
        case skillId = "skill_id"
        case level
        case title
        case levelDescription = "level_description"
    }

    func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["skill_id"] = skillId
        container["level"] = level
        container["title"] = title
        container["level_description"] = levelDescription
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }

    static let skill = belongsTo(Skill.self, using: ForeignKey(["skill_id"]))
}
