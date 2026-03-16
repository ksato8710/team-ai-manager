import Foundation
import GRDB

struct SlackConfig: Identifiable, Codable, Hashable {
    var id: Int64?
    var botToken: String
    var workspaceName: String?
    var isActive: Bool
    var createdAt: String?
    var updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case botToken = "bot_token"
        case workspaceName = "workspace_name"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

extension SlackConfig: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "slack_config"

    enum Columns: String, ColumnExpression {
        case id
        case botToken = "bot_token"
        case workspaceName = "workspace_name"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["bot_token"] = botToken
        container["workspace_name"] = workspaceName
        container["is_active"] = isActive
        if let createdAt { container["created_at"] = createdAt }
        if let updatedAt { container["updated_at"] = updatedAt }
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }

    /// Get the active Slack config (singleton pattern)
    static func current(db: Database) throws -> SlackConfig? {
        try SlackConfig.filter(Columns.isActive == true).fetchOne(db)
    }

    /// Save or update the singleton config
    @discardableResult
    static func saveConfig(db: Database, botToken: String, workspaceName: String?) throws -> SlackConfig {
        // Deactivate any existing
        try db.execute(sql: "UPDATE slack_config SET is_active = 0")

        var config = SlackConfig(botToken: botToken, workspaceName: workspaceName, isActive: true)
        try config.insert(db)
        return config
    }
}
