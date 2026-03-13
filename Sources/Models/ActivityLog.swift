import Foundation
import GRDB

// MARK: - Scan Source Type
enum ScanSourceType: String, Codable, CaseIterable, DatabaseValueConvertible {
    case figma, github, slack, jira, notion, googleDrive = "google_drive", calendar, manual

    var displayName: String {
        switch self {
        case .figma: return "Figma"
        case .github: return "GitHub"
        case .slack: return "Slack"
        case .jira: return "Jira"
        case .notion: return "Notion"
        case .googleDrive: return "Google Drive"
        case .calendar: return "Calendar"
        case .manual: return "Manual"
        }
    }

    var icon: String {
        switch self {
        case .figma: return "paintbrush"
        case .github: return "chevron.left.forwardslash.chevron.right"
        case .slack: return "message"
        case .jira: return "checklist"
        case .notion: return "doc.text"
        case .googleDrive: return "externaldrive"
        case .calendar: return "calendar"
        case .manual: return "hand.raised"
        }
    }
}

// MARK: - Scan Source Status
enum ScanSourceStatus: String, Codable, CaseIterable, DatabaseValueConvertible {
    case active, paused, error, disabled

    var displayName: String { rawValue.capitalized }
}

// MARK: - Entity Type
enum EntityType: String, Codable, CaseIterable, DatabaseValueConvertible {
    case member, project, client, knowledge, team

    var displayName: String { rawValue.capitalized }
}

// MARK: - Scan Source
struct ScanSource: Identifiable, Codable, Hashable {
    var id: Int64?
    var name: String
    var sourceType: ScanSourceType
    var config: String // JSON
    var status: ScanSourceStatus
    var scanIntervalMinutes: Int
    var lastScannedAt: String?
    var lastError: String?
    var createdAt: String?
    var updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name
        case sourceType = "source_type"
        case config, status
        case scanIntervalMinutes = "scan_interval_minutes"
        case lastScannedAt = "last_scanned_at"
        case lastError = "last_error"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

extension ScanSource: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "scan_sources"

    enum Columns: String, ColumnExpression {
        case id, name, sourceType = "source_type", config
        case status, scanIntervalMinutes = "scan_interval_minutes"
        case lastScannedAt = "last_scanned_at", lastError = "last_error"
        case createdAt = "created_at", updatedAt = "updated_at"
    }

    func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["name"] = name
        container["source_type"] = sourceType
        container["config"] = config
        container["status"] = status
        container["scan_interval_minutes"] = scanIntervalMinutes
        container["last_scanned_at"] = lastScannedAt
        container["last_error"] = lastError
        if let createdAt { container["created_at"] = createdAt }
        if let updatedAt { container["updated_at"] = updatedAt }
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

// MARK: - Activity Log
struct ActivityLog: Identifiable, Codable, Hashable {
    var id: Int64?
    var scanSourceId: Int64?
    var sourceType: ScanSourceType
    var entityType: EntityType
    var entityId: Int64
    var action: String?
    var rawData: String?
    var processedData: String?
    var occurredAt: String
    var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case scanSourceId = "scan_source_id"
        case sourceType = "source_type"
        case entityType = "entity_type"
        case entityId = "entity_id"
        case action
        case rawData = "raw_data"
        case processedData = "processed_data"
        case occurredAt = "occurred_at"
        case createdAt = "created_at"
    }
}

extension ActivityLog: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "activity_logs"

    enum Columns: String, ColumnExpression {
        case id, scanSourceId = "scan_source_id", sourceType = "source_type"
        case entityType = "entity_type", entityId = "entity_id"
        case action, rawData = "raw_data", processedData = "processed_data"
        case occurredAt = "occurred_at", createdAt = "created_at"
    }

    func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["scan_source_id"] = scanSourceId
        container["source_type"] = sourceType
        container["entity_type"] = entityType
        container["entity_id"] = entityId
        container["action"] = action
        container["raw_data"] = rawData
        container["processed_data"] = processedData
        container["occurred_at"] = occurredAt
        if let createdAt { container["created_at"] = createdAt }
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

// MARK: - AI Insight
enum InsightType: String, Codable, CaseIterable, DatabaseValueConvertible {
    case workloadAlert = "workload_alert"
    case skillGap = "skill_gap"
    case staffingSuggestion = "staffing_suggestion"
    case projectRisk = "project_risk"
    case growthOpportunity = "growth_opportunity"
    case collaborationPattern = "collaboration_pattern"
    case knowledgeConnection = "knowledge_connection"
    case performanceTrend = "performance_trend"

    var displayName: String {
        switch self {
        case .workloadAlert: return "Workload Alert"
        case .skillGap: return "Skill Gap"
        case .staffingSuggestion: return "Staffing Suggestion"
        case .projectRisk: return "Project Risk"
        case .growthOpportunity: return "Growth Opportunity"
        case .collaborationPattern: return "Collaboration Pattern"
        case .knowledgeConnection: return "Knowledge Connection"
        case .performanceTrend: return "Performance Trend"
        }
    }

    var icon: String {
        switch self {
        case .workloadAlert: return "exclamationmark.triangle"
        case .skillGap: return "star.slash"
        case .staffingSuggestion: return "person.badge.plus"
        case .projectRisk: return "flag"
        case .growthOpportunity: return "arrow.up.right"
        case .collaborationPattern: return "link"
        case .knowledgeConnection: return "book.closed"
        case .performanceTrend: return "chart.line.uptrend.xyaxis"
        }
    }
}

struct AIInsight: Identifiable, Codable, Hashable {
    var id: Int64?
    var entityType: EntityType
    var entityId: Int64?
    var insightType: InsightType
    var title: String
    var content: String
    var confidence: Double
    var isDismissed: Bool
    var isActioned: Bool
    var metadata: String?
    var expiresAt: String?
    var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case entityType = "entity_type"
        case entityId = "entity_id"
        case insightType = "insight_type"
        case title, content, confidence
        case isDismissed = "is_dismissed"
        case isActioned = "is_actioned"
        case metadata
        case expiresAt = "expires_at"
        case createdAt = "created_at"
    }
}

extension AIInsight: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "ai_insights"

    enum Columns: String, ColumnExpression {
        case id, entityType = "entity_type", entityId = "entity_id"
        case insightType = "insight_type", title, content, confidence
        case isDismissed = "is_dismissed", isActioned = "is_actioned"
        case metadata, expiresAt = "expires_at", createdAt = "created_at"
    }

    func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["entity_type"] = entityType
        container["entity_id"] = entityId
        container["insight_type"] = insightType
        container["title"] = title
        container["content"] = content
        container["confidence"] = confidence
        container["is_dismissed"] = isDismissed
        container["is_actioned"] = isActioned
        container["metadata"] = metadata
        container["expires_at"] = expiresAt
        if let createdAt { container["created_at"] = createdAt }
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
