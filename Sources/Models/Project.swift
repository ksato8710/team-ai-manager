import Foundation
import GRDB

// MARK: - Project Status
enum ProjectStatus: String, Codable, CaseIterable, DatabaseValueConvertible {
    case discovery
    case proposal
    case active
    case onHold = "on_hold"
    case completed
    case cancelled

    var displayName: String {
        switch self {
        case .discovery: return "Discovery"
        case .proposal: return "Proposal"
        case .active: return "Active"
        case .onHold: return "On Hold"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }

    var color: String {
        switch self {
        case .discovery: return "purple"
        case .proposal: return "blue"
        case .active: return "green"
        case .onHold: return "orange"
        case .completed: return "gray"
        case .cancelled: return "red"
        }
    }
}

// MARK: - Project Phase
enum ProjectPhase: String, Codable, CaseIterable, DatabaseValueConvertible {
    case research, define, ideate, design, develop, test, launch, maintain

    var displayName: String { rawValue.capitalized }
}

// MARK: - Service Type
enum ServiceType: String, Codable, CaseIterable, DatabaseValueConvertible {
    case businessServiceDesign = "business_service_design"
    case digitalProductUx = "digital_product_ux"
    case growthDesign = "growth_design"
    case brandDesign = "brand_design"
    case hrDevelopment = "hr_development"

    var displayName: String {
        switch self {
        case .businessServiceDesign: return "Business & Service Design"
        case .digitalProductUx: return "Digital Product & UX"
        case .growthDesign: return "Growth Design"
        case .brandDesign: return "Brand Design"
        case .hrDevelopment: return "HR Development"
        }
    }
}

// MARK: - Project
struct Project: Identifiable, Codable, Hashable {
    var id: Int64?
    var name: String
    var clientId: Int64?
    var status: ProjectStatus
    var phase: ProjectPhase?
    var serviceType: ServiceType
    var description: String?
    var startDate: String?
    var endDate: String?
    var budgetHours: Double?
    var tags: String? // JSON array
    var createdAt: String?
    var updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name
        case clientId = "client_id"
        case status, phase
        case serviceType = "service_type"
        case description
        case startDate = "start_date"
        case endDate = "end_date"
        case budgetHours = "budget_hours"
        case tags
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

extension Project: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "projects"

    enum Columns: String, ColumnExpression {
        case id, name, clientId = "client_id", status, phase
        case serviceType = "service_type", description
        case startDate = "start_date", endDate = "end_date"
        case budgetHours = "budget_hours", tags
        case createdAt = "created_at", updatedAt = "updated_at"
    }

    func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["name"] = name
        container["client_id"] = clientId
        container["status"] = status
        container["phase"] = phase
        container["service_type"] = serviceType
        container["description"] = description
        container["start_date"] = startDate
        container["end_date"] = endDate
        container["budget_hours"] = budgetHours
        container["tags"] = tags
        if let createdAt { container["created_at"] = createdAt }
        if let updatedAt { container["updated_at"] = updatedAt }
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }

    static let client = belongsTo(Client.self, using: ForeignKey(["client_id"]))
    static let projectMembers = hasMany(ProjectMember.self)
}
