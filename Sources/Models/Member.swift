import Foundation
import GRDB

// MARK: - Grade (Hierarchy Level)
enum Grade: String, Codable, CaseIterable, DatabaseValueConvertible {
    case ic = "ic"
    case lead = "lead"
    case associatePrincipal = "associate_principal"
    case principal = "principal"
    case executivePrincipal = "executive_principal"
    case executiveOfficer = "executive_officer"

    var displayName: String {
        switch self {
        case .ic: return "Individual Contributor"
        case .lead: return "Lead"
        case .associatePrincipal: return "Associate Principal"
        case .principal: return "Principal"
        case .executivePrincipal: return "Executive Principal"
        case .executiveOfficer: return "Executive Officer"
        }
    }

    var sortOrder: Int {
        switch self {
        case .ic: return 0
        case .lead: return 1
        case .associatePrincipal: return 2
        case .principal: return 3
        case .executivePrincipal: return 4
        case .executiveOfficer: return 5
        }
    }
}

// MARK: - Member Status
enum MemberStatus: String, Codable, CaseIterable, DatabaseValueConvertible {
    case active
    case onLeave = "on_leave"
    case offboarded

    var displayName: String {
        switch self {
        case .active: return "Active"
        case .onLeave: return "On Leave"
        case .offboarded: return "Offboarded"
        }
    }
}

// MARK: - Member
struct Member: Identifiable, Codable, Hashable {
    var id: Int64?
    var name: String
    var email: String
    var roleId: Int64?
    var grade: Grade
    var joinDate: String?
    var avatarUrl: String?
    var status: MemberStatus
    var bio: String?
    var specializations: String? // JSON array
    var weeklyCapacityHours: Double
    var createdAt: String?
    var updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, email
        case roleId = "role_id"
        case grade
        case joinDate = "join_date"
        case avatarUrl = "avatar_url"
        case status, bio, specializations
        case weeklyCapacityHours = "weekly_capacity_hours"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var specializationList: [String] {
        guard let data = specializations?.data(using: .utf8),
              let array = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return array
    }

    var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}

extension Member: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "members"

    enum Columns: String, ColumnExpression {
        case id, name, email, roleId = "role_id", grade, joinDate = "join_date"
        case avatarUrl = "avatar_url", status, bio, specializations
        case weeklyCapacityHours = "weekly_capacity_hours"
        case createdAt = "created_at", updatedAt = "updated_at"
    }

    func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["name"] = name
        container["email"] = email
        container["role_id"] = roleId
        container["grade"] = grade
        container["join_date"] = joinDate
        container["avatar_url"] = avatarUrl
        container["status"] = status
        container["bio"] = bio
        container["specializations"] = specializations
        container["weekly_capacity_hours"] = weeklyCapacityHours
        if let createdAt { container["created_at"] = createdAt }
        if let updatedAt { container["updated_at"] = updatedAt }
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }

    // Associations
    static let role = belongsTo(Role.self, using: ForeignKey(["role_id"]))
    static let memberSkills = hasMany(MemberSkill.self)
    static let projectMembers = hasMany(ProjectMember.self)
}
