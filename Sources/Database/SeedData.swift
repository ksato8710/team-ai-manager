import Foundation
import GRDB

/// Seeds the database from JSON files in Data/organization/ or Data/organization.sample/
struct SeedData {
    private static let seedHashKey = "seedDataHash"

    /// Seed files that are tracked for changes
    private static let seedFiles = [
        "roles.json", "skills.json", "clients.json", "members.json",
        "projects.json", "assignments.json", "knowledge.json", "insights.json"
    ]

    /// Seed if empty, or re-sync if seed data files have changed
    static func seedIfEmpty(db: DatabaseManager) throws {
        let dataDir = resolveDataDirectory()
        let currentHash = computeSeedHash(from: dataDir)
        let storedHash = UserDefaults.standard.string(forKey: seedHashKey)

        let isEmpty = try db.read { db in
            try Member.fetchCount(db) == 0
        }

        if isEmpty {
            print("SEED: Database is empty, seeding...")
            try performSeed(db: db, from: dataDir)
            UserDefaults.standard.set(currentHash, forKey: seedHashKey)
        } else if currentHash != storedHash {
            print("SEED: Seed data changed (hash mismatch), re-syncing...")
            try resync(db: db, from: dataDir)
            UserDefaults.standard.set(currentHash, forKey: seedHashKey)
        }
    }

    /// Force re-sync: clear organization data and re-seed from JSON.
    /// Preserves user-created data (project charters, charter conversations).
    static func forceResync(db: DatabaseManager) throws {
        let dataDir = resolveDataDirectory()
        try resync(db: db, from: dataDir)
        let currentHash = computeSeedHash(from: dataDir)
        UserDefaults.standard.set(currentHash, forKey: seedHashKey)
    }

    // MARK: - Internal

    private static func performSeed(db: DatabaseManager, from dataDir: URL) throws {
        print("SEED: Loading data from \(dataDir.path)")
        try db.write { db in
            let roleIds = try seedRoles(db: db, from: dataDir)
            let skillIds = try seedSkills(db: db, from: dataDir)
            let clientIds = try seedClients(db: db, from: dataDir)
            let memberIds = try seedMembers(db: db, from: dataDir, roleIds: roleIds)
            let projectIds = try seedProjects(db: db, from: dataDir, clientIds: clientIds)
            try seedAssignments(db: db, from: dataDir, memberIds: memberIds, skillIds: skillIds, projectIds: projectIds)
            try seedKnowledge(db: db, from: dataDir, memberIds: memberIds)
            try seedInsights(db: db, from: dataDir, memberIds: memberIds, projectIds: projectIds)
        }
    }

    private static func resync(db: DatabaseManager, from dataDir: URL) throws {
        print("SEED: Clearing organization data (preserving charters)...")
        // Clear seeded tables in dependency order. Preserve project_charters & charter_conversations.
        try db.write { db in
            try db.execute(sql: "DELETE FROM ai_insights")
            try db.execute(sql: "DELETE FROM activity_logs")
            try db.execute(sql: "DELETE FROM knowledge")
            try db.execute(sql: "DELETE FROM project_members")
            try db.execute(sql: "DELETE FROM member_skills")
            try db.execute(sql: "DELETE FROM skill_level_definitions")
            try db.execute(sql: "DELETE FROM projects")
            try db.execute(sql: "DELETE FROM members")
            try db.execute(sql: "DELETE FROM clients")
            try db.execute(sql: "DELETE FROM skills")
            try db.execute(sql: "DELETE FROM roles")
            try db.execute(sql: "DELETE FROM scan_sources")
        }
        try performSeed(db: db, from: dataDir)
        print("SEED: Re-sync complete")
    }

    /// Compute a hash from seed file contents to detect changes
    private static func computeSeedHash(from dataDir: URL) -> String {
        var combined = ""
        for file in seedFiles {
            let url = dataDir.appendingPathComponent(file)
            if let data = try? Data(contentsOf: url) {
                combined += "\(file):\(data.count):\(data.hashValue);"
            }
        }
        // Simple hash: use string hash as hex
        let hash = combined.utf8.reduce(into: UInt64(5381)) { result, byte in
            result = result &* 33 &+ UInt64(byte)
        }
        return String(hash, radix: 16)
    }

    // MARK: - Data Directory Resolution

    private static func resolveDataDirectory() -> URL {
        // Look for Data/organization/ relative to the executable, then fallback to organization.sample/
        let candidates = [
            Bundle.main.bundleURL.deletingLastPathComponent(), // .build/debug/
            Bundle.main.bundleURL, // inside .app bundle
        ]

        for base in candidates {
            // Walk up to find the project root (where Package.swift lives)
            var dir = base
            for _ in 0..<10 {
                let orgDir = dir.appendingPathComponent("Data/organization")
                let packageFile = dir.appendingPathComponent("Package.swift")
                if FileManager.default.fileExists(atPath: packageFile.path) {
                    if FileManager.default.fileExists(atPath: orgDir.path) {
                        return orgDir
                    }
                    let sampleDir = dir.appendingPathComponent("Data/organization.sample")
                    if FileManager.default.fileExists(atPath: sampleDir.path) {
                        print("SEED: organization/ not found, using organization.sample/")
                        return sampleDir
                    }
                }
                dir = dir.deletingLastPathComponent()
            }
        }

        // Last resort: relative to current working directory
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let orgDir = cwd.appendingPathComponent("Data/organization")
        if FileManager.default.fileExists(atPath: orgDir.path) {
            return orgDir
        }
        return cwd.appendingPathComponent("Data/organization.sample")
    }

    private static func loadJSON<T: Decodable>(_ type: T.Type, from dir: URL, file: String) throws -> T {
        let url = dir.appendingPathComponent(file)
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }

    // MARK: - Seed Functions

    private static func seedRoles(db: Database, from dir: URL) throws -> [String: Int64] {
        struct RoleJSON: Decodable {
            let title: String
            let department: String?
            let description: String?
        }
        let items = try loadJSON([RoleJSON].self, from: dir, file: "roles.json")
        var ids: [String: Int64] = [:]
        for item in items {
            var role = Role(title: item.title, description: item.description, department: item.department)
            try role.insert(db)
            ids[item.title] = role.id!
        }
        print("SEED: \(ids.count) roles")
        return ids
    }

    private static func seedSkills(db: Database, from dir: URL) throws -> [String: Int64] {
        struct LevelDefJSON: Decodable {
            let level: Int
            let title: String
            let description: String
        }
        struct SkillJSON: Decodable {
            let name: String
            let category: String
            let description: String?
            let levelDefinitions: [LevelDefJSON]?
        }
        let items = try loadJSON([SkillJSON].self, from: dir, file: "skills.json")
        var ids: [String: Int64] = [:]
        for item in items {
            guard let cat = SkillCategory(rawValue: item.category) else {
                print("SEED: Unknown skill category '\(item.category)' for \(item.name), skipping")
                continue
            }
            var skill = Skill(name: item.name, category: cat, description: item.description)
            try skill.insert(db)
            let skillId = skill.id!
            ids[item.name] = skillId

            if let defs = item.levelDefinitions {
                for def in defs {
                    var levelDef = SkillLevelDefinition(
                        skillId: skillId, level: def.level,
                        title: def.title, levelDescription: def.description
                    )
                    try levelDef.insert(db)
                }
            }
        }
        print("SEED: \(ids.count) skills")
        return ids
    }

    private static func seedClients(db: Database, from dir: URL) throws -> [String: Int64] {
        struct ClientJSON: Decodable {
            let name: String
            let industry: String
            let domain: String?
            let relationshipStatus: String?
            let website: String?
            let notes: String?
        }
        let items = try loadJSON([ClientJSON].self, from: dir, file: "clients.json")
        var ids: [String: Int64] = [:]
        for item in items {
            guard let industry = ClientIndustry(rawValue: item.industry) else {
                print("SEED: Unknown industry '\(item.industry)' for \(item.name), skipping")
                continue
            }
            let status = RelationshipStatus(rawValue: item.relationshipStatus ?? "prospect") ?? .prospect
            var client = Client(
                name: item.name, industry: industry, domain: item.domain,
                relationshipStatus: status, notes: item.notes, website: item.website
            )
            try client.insert(db)
            ids[item.name] = client.id!
        }
        print("SEED: \(ids.count) clients")
        return ids
    }

    private static func seedMembers(db: Database, from dir: URL, roleIds: [String: Int64]) throws -> [String: Int64] {
        struct MemberJSON: Decodable {
            let name: String
            let email: String
            let role: String?
            let grade: String?
            let avatarUrl: String?
            let status: String?
            let bio: String?
            let specializations: [String]?
        }
        let items = try loadJSON([MemberJSON].self, from: dir, file: "members.json")
        var ids: [String: Int64] = [:]
        for item in items {
            let grade = Grade(rawValue: item.grade ?? "ic") ?? .ic
            let status = MemberStatus(rawValue: item.status ?? "active") ?? .active
            let specs: String? = item.specializations.map { array in
                let data = try? JSONEncoder().encode(array)
                return data.flatMap { String(data: $0, encoding: .utf8) }
            } ?? nil
            var member = Member(
                name: item.name, email: item.email,
                roleId: item.role.flatMap { roleIds[$0] },
                grade: grade, avatarUrl: item.avatarUrl,
                status: status, bio: item.bio,
                specializations: specs,
                weeklyCapacityHours: 40.0
            )
            try member.insert(db)
            ids[item.name] = member.id!
        }
        print("SEED: \(ids.count) members")
        return ids
    }

    private static func seedProjects(db: Database, from dir: URL, clientIds: [String: Int64]) throws -> [String: Int64] {
        struct ProjectJSON: Decodable {
            let name: String
            let client: String?
            let status: String?
            let phase: String?
            let serviceType: String
            let description: String?
            let startDate: String?
            let endDate: String?
        }
        let items = try loadJSON([ProjectJSON].self, from: dir, file: "projects.json")
        var ids: [String: Int64] = [:]
        for item in items {
            let status = ProjectStatus(rawValue: item.status ?? "discovery") ?? .discovery
            let phase = item.phase.flatMap { ProjectPhase(rawValue: $0) }
            guard let serviceType = ServiceType(rawValue: item.serviceType) else {
                print("SEED: Unknown serviceType '\(item.serviceType)' for \(item.name), skipping")
                continue
            }
            var project = Project(
                name: item.name,
                clientId: item.client.flatMap { clientIds[$0] },
                status: status, phase: phase,
                serviceType: serviceType,
                description: item.description,
                startDate: item.startDate,
                endDate: item.endDate
            )
            try project.insert(db)
            ids[item.name] = project.id!
        }
        print("SEED: \(ids.count) projects")
        return ids
    }

    private static func seedAssignments(
        db: Database, from dir: URL,
        memberIds: [String: Int64], skillIds: [String: Int64], projectIds: [String: Int64]
    ) throws {
        struct ProjectMemberJSON: Decodable {
            let project: String
            let member: String
            let roleInProject: String?
            let allocationPct: Int?
        }
        struct MemberSkillJSON: Decodable {
            let member: String
            let skill: String
            let proficiency: Int
        }
        struct AssignmentsJSON: Decodable {
            let projectMembers: [ProjectMemberJSON]
            let memberSkills: [MemberSkillJSON]
        }
        let data = try loadJSON(AssignmentsJSON.self, from: dir, file: "assignments.json")

        var pmCount = 0
        for item in data.projectMembers {
            guard let pId = projectIds[item.project], let mId = memberIds[item.member] else { continue }
            var pm = ProjectMember(
                projectId: pId, memberId: mId,
                roleInProject: item.roleInProject,
                allocationPct: item.allocationPct ?? 100,
                isActive: true
            )
            try pm.insert(db)
            pmCount += 1
        }

        var msCount = 0
        for item in data.memberSkills {
            guard let mId = memberIds[item.member], let sId = skillIds[item.skill] else { continue }
            var ms = MemberSkill(memberId: mId, skillId: sId, proficiency: item.proficiency)
            try ms.insert(db)
            msCount += 1
        }
        print("SEED: \(pmCount) project assignments, \(msCount) skill assignments")
    }

    private static func seedKnowledge(db: Database, from dir: URL, memberIds: [String: Int64]) throws {
        struct KnowledgeJSON: Decodable {
            let title: String
            let content: String
            let category: String
            let author: String?
            let isPublished: Bool?
        }
        let items = try loadJSON([KnowledgeJSON].self, from: dir, file: "knowledge.json")
        var count = 0
        for item in items {
            guard let cat = KnowledgeCategory(rawValue: item.category) else {
                print("SEED: Unknown knowledge category '\(item.category)' for \(item.title), skipping")
                continue
            }
            var knowledge = Knowledge(
                title: item.title, content: item.content,
                category: cat,
                authorId: item.author.flatMap { memberIds[$0] },
                isPublished: item.isPublished ?? true
            )
            try knowledge.insert(db)
            count += 1
        }
        print("SEED: \(count) knowledge entries")
    }

    private static func seedInsights(
        db: Database, from dir: URL,
        memberIds: [String: Int64], projectIds: [String: Int64]
    ) throws {
        struct InsightJSON: Decodable {
            let entityType: String
            let entityId: String?
            let insightType: String
            let title: String
            let content: String
            let confidence: Double
        }
        let items = try loadJSON([InsightJSON].self, from: dir, file: "insights.json")
        var count = 0
        for item in items {
            guard let entityType = EntityType(rawValue: item.entityType),
                  let insightType = InsightType(rawValue: item.insightType) else { continue }
            // Resolve entityId from name
            let entityId: Int64? = item.entityId.flatMap { name in
                switch entityType {
                case .member: return memberIds[name]
                case .project: return projectIds[name]
                case .team, .client, .knowledge: return nil
                }
            }
            var insight = AIInsight(
                entityType: entityType, entityId: entityId,
                insightType: insightType,
                title: item.title, content: item.content,
                confidence: item.confidence,
                isDismissed: false, isActioned: false
            )
            try insight.insert(db)
            count += 1
        }
        print("SEED: \(count) AI insights")
    }
}
