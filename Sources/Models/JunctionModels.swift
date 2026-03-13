import Foundation
import GRDB

// MARK: - MemberSkill (Members <-> Skills)
struct MemberSkill: Identifiable, Codable, Hashable {
    var id: Int64?
    var memberId: Int64
    var skillId: Int64
    var proficiency: Int // 1-5
    var lastAssessed: String?
    var notes: String?
    var createdAt: String?
    var updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case memberId = "member_id"
        case skillId = "skill_id"
        case proficiency
        case lastAssessed = "last_assessed"
        case notes
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var proficiencyLabel: String {
        switch proficiency {
        case 1: return "Beginner"
        case 2: return "Developing"
        case 3: return "Proficient"
        case 4: return "Advanced"
        case 5: return "Expert"
        default: return "Unknown"
        }
    }
}

extension MemberSkill: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "member_skills"

    enum Columns: String, ColumnExpression {
        case id, memberId = "member_id", skillId = "skill_id"
        case proficiency, lastAssessed = "last_assessed", notes
        case createdAt = "created_at", updatedAt = "updated_at"
    }

    func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["member_id"] = memberId
        container["skill_id"] = skillId
        container["proficiency"] = proficiency
        container["last_assessed"] = lastAssessed
        container["notes"] = notes
        if let createdAt { container["created_at"] = createdAt }
        if let updatedAt { container["updated_at"] = updatedAt }
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }

    static let member = belongsTo(Member.self, using: ForeignKey(["member_id"]))
    static let skill = belongsTo(Skill.self, using: ForeignKey(["skill_id"]))
}

// MARK: - ProjectMember (Projects <-> Members)
struct ProjectMember: Identifiable, Codable, Hashable {
    var id: Int64?
    var projectId: Int64
    var memberId: Int64
    var roleInProject: String?
    var allocationPct: Int
    var startDate: String?
    var endDate: String?
    var isActive: Bool
    var createdAt: String?
    var updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case projectId = "project_id"
        case memberId = "member_id"
        case roleInProject = "role_in_project"
        case allocationPct = "allocation_pct"
        case startDate = "start_date"
        case endDate = "end_date"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

extension ProjectMember: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "project_members"

    enum Columns: String, ColumnExpression {
        case id, projectId = "project_id", memberId = "member_id"
        case roleInProject = "role_in_project", allocationPct = "allocation_pct"
        case startDate = "start_date", endDate = "end_date", isActive = "is_active"
        case createdAt = "created_at", updatedAt = "updated_at"
    }

    func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["project_id"] = projectId
        container["member_id"] = memberId
        container["role_in_project"] = roleInProject
        container["allocation_pct"] = allocationPct
        container["start_date"] = startDate
        container["end_date"] = endDate
        container["is_active"] = isActive
        if let createdAt { container["created_at"] = createdAt }
        if let updatedAt { container["updated_at"] = updatedAt }
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }

    static let project = belongsTo(Project.self, using: ForeignKey(["project_id"]))
    static let member = belongsTo(Member.self, using: ForeignKey(["member_id"]))
}
