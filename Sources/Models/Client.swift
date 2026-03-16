import Foundation
import GRDB

enum ClientIndustry: String, Codable, CaseIterable, DatabaseValueConvertible {
    case fintech, government, enterprise, healthcare, retail, education, other

    var displayName: String { rawValue.capitalized }
}

enum RelationshipStatus: String, Codable, CaseIterable, DatabaseValueConvertible {
    case prospect, active, inactive, churned

    var displayName: String { rawValue.capitalized }

    var color: String {
        switch self {
        case .prospect: return "blue"
        case .active: return "green"
        case .inactive: return "gray"
        case .churned: return "red"
        }
    }
}

struct Client: Identifiable, Codable, Hashable {
    var id: Int64?
    var name: String
    var industry: ClientIndustry
    var domain: String?
    var contactName: String?
    var contactEmail: String?
    var contactPhone: String?
    var relationshipStatus: RelationshipStatus
    var notes: String?
    var website: String?
    var slackChannelId: String?
    var createdAt: String?
    var updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, industry, domain
        case contactName = "contact_name"
        case contactEmail = "contact_email"
        case contactPhone = "contact_phone"
        case relationshipStatus = "relationship_status"
        case notes, website
        case slackChannelId = "slack_channel_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

extension Client: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "clients"

    enum Columns: String, ColumnExpression {
        case id, name, industry, domain
        case contactName = "contact_name", contactEmail = "contact_email"
        case contactPhone = "contact_phone"
        case relationshipStatus = "relationship_status"
        case notes, website
        case slackChannelId = "slack_channel_id"
        case createdAt = "created_at", updatedAt = "updated_at"
    }

    func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["name"] = name
        container["industry"] = industry
        container["domain"] = domain
        container["contact_name"] = contactName
        container["contact_email"] = contactEmail
        container["contact_phone"] = contactPhone
        container["relationship_status"] = relationshipStatus
        container["notes"] = notes
        container["website"] = website
        container["slack_channel_id"] = slackChannelId
        if let createdAt { container["created_at"] = createdAt }
        if let updatedAt { container["updated_at"] = updatedAt }
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }

    static let projects = hasMany(Project.self)
}
