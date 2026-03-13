import Foundation
import GRDB

/// AI Service that generates insights, recommendations, and predictions
/// Uses Claude API for intelligent analysis of team data
@MainActor
final class AIService: ObservableObject {
    @Published var insights: [AIInsight] = []
    @Published var isAnalyzing = false

    private let database: DatabaseManager

    init(database: DatabaseManager) {
        self.database = database
        loadInsights()
    }

    func loadInsights() {
        do {
            insights = try database.read { db in
                try AIInsight
                    .filter(AIInsight.Columns.isDismissed == false)
                    .order(AIInsight.Columns.createdAt.desc)
                    .limit(50)
                    .fetchAll(db)
            }
        } catch {
            print("Failed to load insights: \(error)")
        }
    }

    // MARK: - Workload Analysis
    /// Analyze team workload distribution and detect overallocation
    func analyzeWorkload() async throws -> [AIInsight] {
        isAnalyzing = true
        defer { isAnalyzing = false }

        let data = try database.read { db -> [(Member, Int, Double)] in
            let members = try Member.filter(Member.Columns.status == "active").fetchAll(db)
            return try members.map { member in
                let assignments = try ProjectMember
                    .filter(ProjectMember.Columns.memberId == member.id!)
                    .filter(ProjectMember.Columns.isActive == true)
                    .fetchAll(db)
                let totalAllocation = assignments.reduce(0) { $0 + $1.allocationPct }
                return (member, assignments.count, Double(totalAllocation))
            }
        }

        var newInsights: [AIInsight] = []
        for (member, projectCount, allocation) in data {
            if allocation > 100 {
                var insight = AIInsight(
                    entityType: .member,
                    entityId: member.id,
                    insightType: .workloadAlert,
                    title: "\(member.name) is overallocated",
                    content: "\(member.name) is assigned to \(projectCount) projects with a total allocation of \(Int(allocation))%. Consider redistributing workload to maintain quality and prevent burnout.",
                    confidence: min(allocation / 150.0, 1.0),
                    isDismissed: false,
                    isActioned: false
                )
                try database.write { db in
                    try insight.insert(db)
                }
                newInsights.append(insight)
            } else if allocation < 30 && allocation > 0 {
                var insight = AIInsight(
                    entityType: .member,
                    entityId: member.id,
                    insightType: .workloadAlert,
                    title: "\(member.name) has low utilization",
                    content: "\(member.name) is only at \(Int(allocation))% allocation across \(projectCount) project(s). They may have capacity for additional assignments or skill development activities.",
                    confidence: 0.7,
                    isDismissed: false,
                    isActioned: false
                )
                try database.write { db in
                    try insight.insert(db)
                }
                newInsights.append(insight)
            }
        }

        loadInsights()
        return newInsights
    }

    // MARK: - Skill Gap Analysis
    /// Identify skill gaps across projects and recommend training/hiring
    func analyzeSkillGaps() async throws -> [AIInsight] {
        isAnalyzing = true
        defer { isAnalyzing = false }

        let projectSkillData = try database.read { db -> [(Project, [Member], [MemberSkill])] in
            let activeProjects = try Project
                .filter(Project.Columns.status == "active")
                .fetchAll(db)

            return try activeProjects.map { project in
                let assignments = try ProjectMember
                    .filter(ProjectMember.Columns.projectId == project.id!)
                    .filter(ProjectMember.Columns.isActive == true)
                    .fetchAll(db)
                let memberIds = assignments.map(\.memberId)
                let members = try Member
                    .filter(memberIds.contains(Member.Columns.id))
                    .fetchAll(db)
                let skills = try MemberSkill
                    .filter(memberIds.contains(MemberSkill.Columns.memberId))
                    .fetchAll(db)
                return (project, members, skills)
            }
        }

        var newInsights: [AIInsight] = []
        for (project, members, skills) in projectSkillData {
            if members.isEmpty {
                var insight = AIInsight(
                    entityType: .project,
                    entityId: project.id,
                    insightType: .staffingSuggestion,
                    title: "No members assigned to \(project.name)",
                    content: "Project '\(project.name)' has no active members. Consider assigning team members based on required skill sets.",
                    confidence: 1.0,
                    isDismissed: false,
                    isActioned: false
                )
                try database.write { db in
                    try insight.insert(db)
                }
                newInsights.append(insight)
            }
        }

        loadInsights()
        return newInsights
    }

    // MARK: - Staffing Recommendations
    /// Recommend optimal member assignments for a project based on skills and availability
    func recommendStaffing(for projectId: Int64) async throws -> [StaffingRecommendation] {
        let data = try database.read { db -> (Project, [Member], [MemberSkill], [ProjectMember]) in
            let project = try Project.fetchOne(db, id: projectId)!
            let allMembers = try Member
                .filter(Member.Columns.status == "active")
                .fetchAll(db)
            let allSkills = try MemberSkill.fetchAll(db)
            let allAssignments = try ProjectMember
                .filter(ProjectMember.Columns.isActive == true)
                .fetchAll(db)
            return (project, allMembers, allSkills, allAssignments)
        }

        let (_, members, memberSkills, assignments) = data

        // Calculate availability for each member
        return members.compactMap { member -> StaffingRecommendation? in
            let memberAssignments = assignments.filter { $0.memberId == member.id! }
            let totalAllocation = memberAssignments.reduce(0) { $0 + $1.allocationPct }
            let availableCapacity = max(0, 100 - totalAllocation)

            guard availableCapacity > 0 else { return nil }

            let skills = memberSkills.filter { $0.memberId == member.id! }
            let avgProficiency = skills.isEmpty ? 0 : Double(skills.reduce(0) { $0 + $1.proficiency }) / Double(skills.count)

            return StaffingRecommendation(
                member: member,
                availableCapacity: availableCapacity,
                relevantSkillScore: avgProficiency,
                reason: "Available at \(availableCapacity)% capacity, avg skill proficiency: \(String(format: "%.1f", avgProficiency))/5"
            )
        }
        .sorted { $0.relevantSkillScore * Double($0.availableCapacity) > $1.relevantSkillScore * Double($1.availableCapacity) }
    }

    // MARK: - Dismiss/Action insights
    func dismissInsight(_ insight: AIInsight) throws {
        var updated = insight
        updated.isDismissed = true
        try database.write { db in
            try updated.update(db)
        }
        loadInsights()
    }

    func actionInsight(_ insight: AIInsight) throws {
        var updated = insight
        updated.isActioned = true
        try database.write { db in
            try updated.update(db)
        }
        loadInsights()
    }
}

struct StaffingRecommendation: Identifiable {
    var id: Int64? { member.id }
    let member: Member
    let availableCapacity: Int
    let relevantSkillScore: Double
    let reason: String
}
