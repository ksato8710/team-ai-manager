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
    /// (Project, ProjectMember, effectiveAllocationPct for this month)
    let assignments: [(Project, ProjectMember, Int)]
    let totalAllocationPct: Int

    private var clientAllocationPct: Int {
        assignments.reduce(0) { $0 + $1.2 }
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
            ForEach(assignments, id: \.1.id) { project, pm, effectivePct in
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

                    AllocationBar(percentage: effectivePct, width: 40)
                    Text("\(effectivePct)%")
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
    /// Fetch total allocation % for each member across all active projects for a given month.
    /// Uses monthly overrides if available, falls back to project_members.allocation_pct.
    static func fetchTotalAllocations(db: Database, yearMonth: String? = nil) throws -> [Int64: Int] {
        let month = yearMonth ?? ProjectMemberAllocation.currentYearMonth
        return try ProjectMemberAllocation.fetchMonthlyTotalAllocations(db: db, yearMonth: month)
    }

    /// Get effective allocation for a specific ProjectMember for a given month.
    static func effectiveAllocation(db: Database, pm: ProjectMember, yearMonth: String? = nil) throws -> Int {
        let month = yearMonth ?? ProjectMemberAllocation.currentYearMonth
        guard let pmId = pm.id else { return pm.allocationPct }
        return try ProjectMemberAllocation.effectiveAllocation(db: db, projectMemberId: pmId, yearMonth: month)
    }

    /// Fetch team members for a client across all projects, grouped by member.
    /// Uses monthly allocations for the specified month.
    static func fetchClientTeam(db: Database, clientId: Int64, yearMonth: String? = nil) throws -> [(Member, [(Project, ProjectMember, Int)])] {
        let month = yearMonth ?? ProjectMemberAllocation.currentYearMonth
        let projects = try Project
            .filter(Project.Columns.clientId == clientId)
            .fetchAll(db)

        // (Member, [(Project, ProjectMember, effectiveAllocationPct)])
        var memberAssignments: [Int64: (Member, [(Project, ProjectMember, Int)])] = [:]

        for project in projects {
            guard let projectId = project.id else { continue }
            let assignments = try ProjectMember
                .filter(ProjectMember.Columns.projectId == projectId)
                .filter(ProjectMember.Columns.isActive == true)
                .fetchAll(db)

            for pm in assignments {
                guard let pmId = pm.id,
                      let member = try Member.fetchOne(db, id: pm.memberId) else { continue }
                let effectivePct = try ProjectMemberAllocation.effectiveAllocation(
                    db: db, projectMemberId: pmId, yearMonth: month
                )
                if var existing = memberAssignments[pm.memberId] {
                    existing.1.append((project, pm, effectivePct))
                    memberAssignments[pm.memberId] = existing
                } else {
                    memberAssignments[pm.memberId] = (member, [(project, pm, effectivePct)])
                }
            }
        }

        return memberAssignments.values
            .sorted { a, b in
                let aTotal = a.1.reduce(0) { $0 + $1.2 }
                let bTotal = b.1.reduce(0) { $0 + $1.2 }
                if aTotal != bTotal { return aTotal > bTotal }
                return a.0.grade.sortOrder > b.0.grade.sortOrder
            }
    }
}
