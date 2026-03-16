import Foundation
import GRDB

/// Monthly allocation override for a project member assignment.
/// If no record exists for a given month, falls back to ProjectMember.allocationPct.
struct ProjectMemberAllocation: Identifiable, Codable, Hashable {
    var id: Int64?
    var projectMemberId: Int64
    var yearMonth: String  // "2026-03"
    var allocationPct: Int

    enum CodingKeys: String, CodingKey {
        case id
        case projectMemberId = "project_member_id"
        case yearMonth = "year_month"
        case allocationPct = "allocation_pct"
    }
}

extension ProjectMemberAllocation: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "project_member_allocations"

    enum Columns: String, ColumnExpression {
        case id
        case projectMemberId = "project_member_id"
        case yearMonth = "year_month"
        case allocationPct = "allocation_pct"
    }

    func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["project_member_id"] = projectMemberId
        container["year_month"] = yearMonth
        container["allocation_pct"] = allocationPct
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }

    static let projectMember = belongsTo(ProjectMember.self, using: ForeignKey(["project_member_id"]))
}

// MARK: - Query Helpers

extension ProjectMemberAllocation {
    /// Get allocation for a specific project member and month.
    /// Falls back to ProjectMember.allocationPct if no monthly record exists.
    static func effectiveAllocation(
        db: Database,
        projectMemberId: Int64,
        yearMonth: String
    ) throws -> Int {
        if let monthly = try ProjectMemberAllocation
            .filter(Columns.projectMemberId == projectMemberId)
            .filter(Columns.yearMonth == yearMonth)
            .fetchOne(db) {
            return monthly.allocationPct
        }
        // Fallback to default
        if let pm = try ProjectMember.fetchOne(db, id: projectMemberId) {
            return pm.allocationPct
        }
        return 0
    }

    /// Get effective allocations for all active project members for a given month.
    /// Returns [memberId: totalAllocationPct]
    static func fetchMonthlyTotalAllocations(
        db: Database,
        yearMonth: String
    ) throws -> [Int64: Int] {
        // Get all active project members
        let activePMs = try ProjectMember
            .filter(ProjectMember.Columns.isActive == true)
            .fetchAll(db)

        // Get monthly overrides for this month
        let monthlyRows = try ProjectMemberAllocation
            .filter(Columns.yearMonth == yearMonth)
            .fetchAll(db)
        let monthlyByPMId = Dictionary(uniqueKeysWithValues: monthlyRows.compactMap { row in
            row.id != nil ? (row.projectMemberId, row.allocationPct) : nil
        }.map { ($0.0, $0.1) })

        // Sum up per member
        var result: [Int64: Int] = [:]
        for pm in activePMs {
            guard let pmId = pm.id else { continue }
            let pct = monthlyByPMId[pmId] ?? pm.allocationPct
            result[pm.memberId, default: 0] += pct
        }
        return result
    }

    /// Get monthly allocations for a specific project member across all months.
    static func fetchAllMonths(
        db: Database,
        projectMemberId: Int64
    ) throws -> [ProjectMemberAllocation] {
        try ProjectMemberAllocation
            .filter(Columns.projectMemberId == projectMemberId)
            .order(Columns.yearMonth)
            .fetchAll(db)
    }

    /// Set allocation for a specific month. Creates or updates.
    @discardableResult
    static func setAllocation(
        db: Database,
        projectMemberId: Int64,
        yearMonth: String,
        allocationPct: Int
    ) throws -> ProjectMemberAllocation {
        if var existing = try ProjectMemberAllocation
            .filter(Columns.projectMemberId == projectMemberId)
            .filter(Columns.yearMonth == yearMonth)
            .fetchOne(db) {
            existing.allocationPct = allocationPct
            try existing.update(db)
            return existing
        } else {
            var new = ProjectMemberAllocation(
                projectMemberId: projectMemberId,
                yearMonth: yearMonth,
                allocationPct: allocationPct
            )
            try new.insert(db)
            return new
        }
    }

    /// Current year-month string
    static var currentYearMonth: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date())
    }
}
