import Foundation
import GRDB

final class DatabaseManager: Sendable {
    static let shared = DatabaseManager()

    let dbPool: DatabasePool

    private init() {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dbDir = appSupport.appendingPathComponent("TeamAIManager", isDirectory: true)

        try! fileManager.createDirectory(at: dbDir, withIntermediateDirectories: true)

        let dbPath = dbDir.appendingPathComponent("team_ai_manager.sqlite").path
        var config = Configuration()
        config.foreignKeysEnabled = true
        config.prepareDatabase { db in
            db.trace { print("SQL: \($0)") }
        }

        dbPool = try! DatabasePool(path: dbPath, configuration: config)
        try! migrator.migrate(dbPool)
    }

    // MARK: - Migrations
    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        #if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
        #endif

        migrator.registerMigration("v1_initial") { db in
            // Clients
            try db.create(table: "clients") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull()
                t.column("industry", .text).notNull()
                t.column("domain", .text)
                t.column("contact_name", .text)
                t.column("contact_email", .text)
                t.column("contact_phone", .text)
                t.column("relationship_status", .text).notNull().defaults(to: "prospect")
                t.column("notes", .text)
                t.column("website", .text)
                t.column("created_at", .text).notNull().defaults(sql: "(datetime('now'))")
                t.column("updated_at", .text).notNull().defaults(sql: "(datetime('now'))")
            }

            // Roles
            try db.create(table: "roles") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("title", .text).notNull().unique()
                t.column("description", .text)
                t.column("department", .text)
                t.column("responsibilities", .text)
                t.column("created_at", .text).notNull().defaults(sql: "(datetime('now'))")
                t.column("updated_at", .text).notNull().defaults(sql: "(datetime('now'))")
            }

            // Members
            try db.create(table: "members") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull()
                t.column("email", .text).notNull().unique()
                t.column("role_id", .integer).references("roles", onDelete: .setNull)
                t.column("grade", .text).notNull().defaults(to: "ic")
                t.column("join_date", .text)
                t.column("avatar_url", .text)
                t.column("status", .text).notNull().defaults(to: "active")
                t.column("bio", .text)
                t.column("specializations", .text)
                t.column("weekly_capacity_hours", .double).defaults(to: 40.0)
                t.column("created_at", .text).notNull().defaults(sql: "(datetime('now'))")
                t.column("updated_at", .text).notNull().defaults(sql: "(datetime('now'))")
            }

            // Skills
            try db.create(table: "skills") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull().unique()
                t.column("category", .text).notNull()
                t.column("description", .text)
                t.column("created_at", .text).notNull().defaults(sql: "(datetime('now'))")
                t.column("updated_at", .text).notNull().defaults(sql: "(datetime('now'))")
            }

            // Projects
            try db.create(table: "projects") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull()
                t.column("client_id", .integer).references("clients", onDelete: .setNull)
                t.column("status", .text).notNull().defaults(to: "discovery")
                t.column("phase", .text)
                t.column("service_type", .text).notNull()
                t.column("description", .text)
                t.column("start_date", .text)
                t.column("end_date", .text)
                t.column("budget_hours", .double)
                t.column("tags", .text)
                t.column("created_at", .text).notNull().defaults(sql: "(datetime('now'))")
                t.column("updated_at", .text).notNull().defaults(sql: "(datetime('now'))")
            }

            // Knowledge
            try db.create(table: "knowledge") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("title", .text).notNull()
                t.column("content", .text).notNull()
                t.column("category", .text).notNull()
                t.column("tags", .text)
                t.column("author_id", .integer).references("members", onDelete: .setNull)
                t.column("project_id", .integer).references("projects", onDelete: .setNull)
                t.column("is_published", .boolean).notNull().defaults(to: true)
                t.column("created_at", .text).notNull().defaults(sql: "(datetime('now'))")
                t.column("updated_at", .text).notNull().defaults(sql: "(datetime('now'))")
            }

            // Member Skills
            try db.create(table: "member_skills") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("member_id", .integer).notNull().references("members", onDelete: .cascade)
                t.column("skill_id", .integer).notNull().references("skills", onDelete: .cascade)
                t.column("proficiency", .integer).notNull().defaults(to: 1)
                t.column("last_assessed", .text)
                t.column("notes", .text)
                t.column("created_at", .text).notNull().defaults(sql: "(datetime('now'))")
                t.column("updated_at", .text).notNull().defaults(sql: "(datetime('now'))")
                t.uniqueKey(["member_id", "skill_id"])
            }

            // Project Members
            try db.create(table: "project_members") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("project_id", .integer).notNull().references("projects", onDelete: .cascade)
                t.column("member_id", .integer).notNull().references("members", onDelete: .cascade)
                t.column("role_in_project", .text)
                t.column("allocation_pct", .integer).defaults(to: 100)
                t.column("start_date", .text)
                t.column("end_date", .text)
                t.column("is_active", .boolean).notNull().defaults(to: true)
                t.column("created_at", .text).notNull().defaults(sql: "(datetime('now'))")
                t.column("updated_at", .text).notNull().defaults(sql: "(datetime('now'))")
                t.uniqueKey(["project_id", "member_id"])
            }

            // Scan Sources
            try db.create(table: "scan_sources") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull()
                t.column("source_type", .text).notNull()
                t.column("config", .text).notNull().defaults(to: "{}")
                t.column("status", .text).notNull().defaults(to: "active")
                t.column("scan_interval_minutes", .integer).defaults(to: 60)
                t.column("last_scanned_at", .text)
                t.column("last_error", .text)
                t.column("created_at", .text).notNull().defaults(sql: "(datetime('now'))")
                t.column("updated_at", .text).notNull().defaults(sql: "(datetime('now'))")
            }

            // Activity Logs
            try db.create(table: "activity_logs") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("scan_source_id", .integer).references("scan_sources")
                t.column("source_type", .text).notNull()
                t.column("entity_type", .text).notNull()
                t.column("entity_id", .integer).notNull()
                t.column("action", .text)
                t.column("raw_data", .text)
                t.column("processed_data", .text)
                t.column("occurred_at", .text).notNull()
                t.column("created_at", .text).notNull().defaults(sql: "(datetime('now'))")
            }
            try db.create(indexOn: "activity_logs", columns: ["entity_type", "entity_id"])
            try db.create(indexOn: "activity_logs", columns: ["occurred_at"])

            // AI Insights
            try db.create(table: "ai_insights") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("entity_type", .text).notNull()
                t.column("entity_id", .integer)
                t.column("insight_type", .text).notNull()
                t.column("title", .text).notNull()
                t.column("content", .text).notNull()
                t.column("confidence", .double).notNull()
                t.column("is_dismissed", .boolean).notNull().defaults(to: false)
                t.column("is_actioned", .boolean).notNull().defaults(to: false)
                t.column("metadata", .text)
                t.column("expires_at", .text)
                t.column("created_at", .text).notNull().defaults(sql: "(datetime('now'))")
            }
            try db.create(indexOn: "ai_insights", columns: ["entity_type", "entity_id"])
            try db.create(indexOn: "ai_insights", columns: ["insight_type"])
        }

        migrator.registerMigration("v2_skill_level_definitions") { db in
            try db.create(table: "skill_level_definitions") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("skill_id", .integer).notNull().references("skills", onDelete: .cascade)
                t.column("level", .integer).notNull()
                t.column("title", .text).notNull()
                t.column("level_description", .text).notNull()
                t.uniqueKey(["skill_id", "level"])
            }
        }

        migrator.registerMigration("v3_project_charters") { db in
            try db.create(table: "project_charters") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("project_id", .integer).references("projects", onDelete: .setNull)
                t.column("title", .text).notNull()
                t.column("status", .text).notNull().defaults(to: "draft")
                t.column("summary", .text)
                t.column("background", .text)
                t.column("objectives", .text)
                t.column("scope", .text)
                t.column("target_users", .text)
                t.column("success_criteria", .text)
                t.column("constraints", .text)
                t.column("deliverables", .text)
                t.column("team", .text)
                t.column("schedule", .text)
                t.column("risks", .text)
                t.column("design_principles", .text)
                t.column("approval_process", .text)
                t.column("full_document", .text)
                t.column("created_at", .text).notNull().defaults(sql: "(datetime('now'))")
                t.column("updated_at", .text).notNull().defaults(sql: "(datetime('now'))")
            }

            try db.create(table: "charter_conversations") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("charter_id", .integer).notNull().references("project_charters", onDelete: .cascade)
                t.column("role", .text).notNull()
                t.column("content", .text).notNull()
                t.column("section_target", .text)
                t.column("created_at", .text).notNull().defaults(sql: "(datetime('now'))")
            }
            try db.create(indexOn: "charter_conversations", columns: ["charter_id"])
        }

        migrator.registerMigration("v4_monthly_allocations") { db in
            try db.create(table: "project_member_allocations") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("project_member_id", .integer).notNull().references("project_members", onDelete: .cascade)
                t.column("year_month", .text).notNull() // "2026-03"
                t.column("allocation_pct", .integer).notNull()
                t.uniqueKey(["project_member_id", "year_month"])
            }
            try db.create(indexOn: "project_member_allocations", columns: ["project_member_id"])
            try db.create(indexOn: "project_member_allocations", columns: ["year_month"])
        }

        return migrator
    }
}

// MARK: - Convenience Read/Write
extension DatabaseManager {
    func read<T>(_ block: (Database) throws -> T) throws -> T {
        try dbPool.read(block)
    }

    func write<T>(_ block: (Database) throws -> T) throws -> T {
        try dbPool.write(block)
    }
}
