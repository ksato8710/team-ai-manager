import Foundation
import GRDB

// MARK: - Charter Status

enum CharterStatus: String, Codable, CaseIterable, DatabaseValueConvertible {
    case draft
    case inProgress = "in_progress"
    case completed

    var displayName: String {
        switch self {
        case .draft: return "Draft"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        }
    }
}

// MARK: - Charter Section

enum CharterSection: String, CaseIterable, Identifiable {
    case summary
    case background
    case objectives
    case scope
    case targetUsers
    case successCriteria
    case constraints
    case deliverables
    case team
    case schedule
    case risks
    case designPrinciples
    case approvalProcess

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .summary: return "概要"
        case .background: return "背景・課題"
        case .objectives: return "目的・ゴール"
        case .scope: return "スコープ"
        case .targetUsers: return "ターゲットユーザー"
        case .successCriteria: return "成功指標（KPI）"
        case .constraints: return "制約・前提条件"
        case .deliverables: return "デリバラブル"
        case .team: return "体制・役割"
        case .schedule: return "スケジュール"
        case .risks: return "リスク"
        case .designPrinciples: return "デザイン方針"
        case .approvalProcess: return "承認・レビュー"
        }
    }

    var icon: String {
        switch self {
        case .summary: return "doc.text"
        case .background: return "lightbulb"
        case .objectives: return "target"
        case .scope: return "rectangle.dashed"
        case .targetUsers: return "person.2"
        case .successCriteria: return "chart.bar"
        case .constraints: return "lock"
        case .deliverables: return "shippingbox"
        case .team: return "person.3"
        case .schedule: return "calendar"
        case .risks: return "exclamationmark.triangle"
        case .designPrinciples: return "paintbrush"
        case .approvalProcess: return "checkmark.seal"
        }
    }

    /// Sections that depend on this section (cascade update targets)
    var dependentSections: [CharterSection] {
        switch self {
        case .scope: return [.deliverables, .schedule, .risks, .team]
        case .targetUsers: return [.designPrinciples, .successCriteria]
        case .schedule: return [.deliverables, .team]
        case .constraints: return [.scope, .schedule, .risks]
        default: return []
        }
    }
}

// MARK: - Project Charter

struct ProjectCharter: Identifiable, Codable, Hashable {
    var id: Int64?
    var projectId: Int64?
    var title: String
    var status: CharterStatus
    var summary: String?
    var background: String?
    var objectives: String?
    var scope: String?
    var targetUsers: String?
    var successCriteria: String?
    var constraints: String?
    var deliverables: String?
    var team: String?
    var schedule: String?
    var risks: String?
    var designPrinciples: String?
    var approvalProcess: String?
    var fullDocument: String?
    var createdAt: String?
    var updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, title, status, summary, background, objectives, scope
        case projectId = "project_id"
        case targetUsers = "target_users"
        case successCriteria = "success_criteria"
        case constraints, deliverables, team, schedule, risks
        case designPrinciples = "design_principles"
        case approvalProcess = "approval_process"
        case fullDocument = "full_document"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// Get content for a specific section
    func content(for section: CharterSection) -> String? {
        switch section {
        case .summary: return summary
        case .background: return background
        case .objectives: return objectives
        case .scope: return scope
        case .targetUsers: return targetUsers
        case .successCriteria: return successCriteria
        case .constraints: return constraints
        case .deliverables: return deliverables
        case .team: return team
        case .schedule: return schedule
        case .risks: return risks
        case .designPrinciples: return designPrinciples
        case .approvalProcess: return approvalProcess
        }
    }

    /// Set content for a specific section
    mutating func setContent(_ content: String?, for section: CharterSection) {
        switch section {
        case .summary: summary = content
        case .background: background = content
        case .objectives: objectives = content
        case .scope: scope = content
        case .targetUsers: targetUsers = content
        case .successCriteria: successCriteria = content
        case .constraints: constraints = content
        case .deliverables: deliverables = content
        case .team: team = content
        case .schedule: schedule = content
        case .risks: risks = content
        case .designPrinciples: designPrinciples = content
        case .approvalProcess: approvalProcess = content
        }
    }

    /// Count of sections that have content
    var filledSectionCount: Int {
        CharterSection.allCases.filter { content(for: $0) != nil && !content(for: $0)!.isEmpty }.count
    }

    var totalSectionCount: Int { CharterSection.allCases.count }
}

extension ProjectCharter: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "project_charters"

    enum Columns: String, ColumnExpression {
        case id, title, status, summary, background, objectives, scope
        case projectId = "project_id"
        case targetUsers = "target_users"
        case successCriteria = "success_criteria"
        case constraints, deliverables, team, schedule, risks
        case designPrinciples = "design_principles"
        case approvalProcess = "approval_process"
        case fullDocument = "full_document"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["project_id"] = projectId
        container["title"] = title
        container["status"] = status
        container["summary"] = summary
        container["background"] = background
        container["objectives"] = objectives
        container["scope"] = scope
        container["target_users"] = targetUsers
        container["success_criteria"] = successCriteria
        container["constraints"] = constraints
        container["deliverables"] = deliverables
        container["team"] = team
        container["schedule"] = schedule
        container["risks"] = risks
        container["design_principles"] = designPrinciples
        container["approval_process"] = approvalProcess
        container["full_document"] = fullDocument
        if let createdAt { container["created_at"] = createdAt }
        if let updatedAt { container["updated_at"] = updatedAt }
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

// MARK: - Charter Conversation Message

struct CharterMessage: Identifiable, Codable, Hashable {
    var id: Int64?
    var charterId: Int64
    var role: String // "user" or "assistant"
    var content: String
    var sectionTarget: String? // which charter section this relates to
    var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, role, content
        case charterId = "charter_id"
        case sectionTarget = "section_target"
        case createdAt = "created_at"
    }

    var isUser: Bool { role == "user" }
    var isAssistant: Bool { role == "assistant" }
}

extension CharterMessage: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "charter_conversations"

    enum Columns: String, ColumnExpression {
        case id, role, content
        case charterId = "charter_id"
        case sectionTarget = "section_target"
        case createdAt = "created_at"
    }

    func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["charter_id"] = charterId
        container["role"] = role
        container["content"] = content
        container["section_target"] = sectionTarget
        if let createdAt { container["created_at"] = createdAt }
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
