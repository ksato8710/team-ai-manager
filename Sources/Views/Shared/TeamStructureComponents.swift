import SwiftUI
import GRDB

// MARK: - Allocation Bar

struct AllocationBar: View {
    let percentage: Int
    let width: CGFloat

    private var color: Color {
        if percentage > 100 { return .red }
        if percentage > 80 { return .orange }
        return .green
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gray.opacity(0.15))
                RoundedRectangle(cornerRadius: 2)
                    .fill(color.gradient)
                    .frame(width: min(geo.size.width, geo.size.width * CGFloat(percentage) / 100.0))
            }
        }
        .frame(width: width, height: 6)
    }
}

// MARK: - Total Allocation Badge

struct TotalAllocationBadge: View {
    let percentage: Int

    private var color: Color {
        if percentage > 100 { return .red }
        if percentage > 80 { return .orange }
        return .green
    }

    var body: some View {
        Text("全体 \(percentage)%")
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Team Member Card (for Project detail)

struct TeamMemberCard: View {
    let member: Member
    let roleInProject: String?
    let allocationPct: Int
    let totalAllocationPct: Int

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(name: member.name, size: 36)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(member.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    GradeBadge(grade: member.grade)
                }
                if let role = roleInProject, !role.isEmpty {
                    Text(role)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 6) {
                    AllocationBar(percentage: allocationPct, width: 60)
                    Text("\(allocationPct)%")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.blue)
                        .frame(width: 36, alignment: .trailing)
                }
                TotalAllocationBadge(percentage: totalAllocationPct)
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Client Team Member Card (multi-project breakdown)

struct ClientTeamMemberCard: View {
    let member: Member
    let assignments: [(Project, ProjectMember)]
    let totalAllocationPct: Int

    private var clientAllocationPct: Int {
        assignments.reduce(0) { $0 + $1.1.allocationPct }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Member header
            HStack(spacing: 10) {
                AvatarView(name: member.name, size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(member.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        GradeBadge(grade: member.grade)
                    }
                }
                Spacer()
                TotalAllocationBadge(percentage: totalAllocationPct)
            }

            // Per-project breakdown
            ForEach(assignments, id: \.1.id) { project, pm in
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.3))
                        .frame(width: 2)
                        .padding(.leading, 20)

                    Text(project.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if let role = pm.roleInProject, !role.isEmpty {
                        Text(role)
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }

                    Spacer()

                    AllocationBar(percentage: pm.allocationPct, width: 40)
                    Text("\(pm.allocationPct)%")
                        .font(.caption)
                        .foregroundStyle(.blue)
                        .frame(width: 30, alignment: .trailing)
                }
            }

            // Client subtotal
            if assignments.count > 1 {
                HStack {
                    Spacer()
                    Text("このクライアント合計: \(clientAllocationPct)%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Team Structure Header

struct TeamStructureHeader: View {
    let memberCount: Int
    let totalAllocation: Int
    let label: String

    var body: some View {
        HStack {
            Text("\(label) (\(memberCount))")
                .font(.headline)
            Spacer()
            Text("稼働合計: \(totalAllocation)%")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Data Query Helpers

enum TeamDataQuery {
    /// Fetch total allocation % for each member across all active projects
    static func fetchTotalAllocations(db: Database) throws -> [Int64: Int] {
        let rows = try Row.fetchAll(db, sql: """
            SELECT member_id, SUM(allocation_pct) as total
            FROM project_members
            WHERE is_active = 1
            GROUP BY member_id
            """)
        var result: [Int64: Int] = [:]
        for row in rows {
            let memberId: Int64 = row["member_id"]
            let total: Int = row["total"]
            result[memberId] = total
        }
        return result
    }

    /// Fetch team members for a client across all projects, grouped by member
    static func fetchClientTeam(db: Database, clientId: Int64) throws -> [(Member, [(Project, ProjectMember)])] {
        let projects = try Project
            .filter(Project.Columns.clientId == clientId)
            .fetchAll(db)

        var memberAssignments: [Int64: (Member, [(Project, ProjectMember)])] = [:]

        for project in projects {
            guard let projectId = project.id else { continue }
            let assignments = try ProjectMember
                .filter(ProjectMember.Columns.projectId == projectId)
                .filter(ProjectMember.Columns.isActive == true)
                .fetchAll(db)

            for pm in assignments {
                guard let member = try Member.fetchOne(db, id: pm.memberId) else { continue }
                if var existing = memberAssignments[pm.memberId] {
                    existing.1.append((project, pm))
                    memberAssignments[pm.memberId] = existing
                } else {
                    memberAssignments[pm.memberId] = (member, [(project, pm)])
                }
            }
        }

        // Sort by total client allocation descending, then by grade
        return memberAssignments.values
            .sorted { a, b in
                let aTotal = a.1.reduce(0) { $0 + $1.1.allocationPct }
                let bTotal = b.1.reduce(0) { $0 + $1.1.allocationPct }
                if aTotal != bTotal { return aTotal > bTotal }
                return a.0.grade.sortOrder > b.0.grade.sortOrder
            }
    }
}
