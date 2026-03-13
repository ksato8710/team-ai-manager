import Foundation
import GRDB

struct Role: Identifiable, Codable, Hashable {
    var id: Int64?
    var title: String
    var description: String?
    var department: String?
    var responsibilities: String? // JSON array
    var createdAt: String?
    var updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, title, description, department, responsibilities
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var responsibilityList: [String] {
        guard let data = responsibilities?.data(using: .utf8),
              let array = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return array
    }
}

extension Role: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "roles"

    enum Columns: String, ColumnExpression {
        case id, title, description, department, responsibilities
        case createdAt = "created_at", updatedAt = "updated_at"
    }

    func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["title"] = title
        container["description"] = description
        container["department"] = department
        container["responsibilities"] = responsibilities
        if let createdAt { container["created_at"] = createdAt }
        if let updatedAt { container["updated_at"] = updatedAt }
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }

    static let members = hasMany(Member.self)
}
