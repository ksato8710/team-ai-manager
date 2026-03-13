import SwiftUI
import GRDB

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @State private var stats = DashboardStats()
    @State private var recentInsights: [AIInsight] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                Text("Dashboard")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                // Stats Cards
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                ], spacing: 16) {
                    StatCard(title: "Active Members", value: "\(stats.activeMembers)", icon: "person.3", color: .blue)
                    StatCard(title: "Active Projects", value: "\(stats.activeProjects)", icon: "folder.fill", color: .green)
                    StatCard(title: "Clients", value: "\(stats.activeClients)", icon: "building.2.fill", color: .purple)
                    StatCard(title: "AI Insights", value: "\(stats.pendingInsights)", icon: "brain", color: .orange)
                }

                // Two-column layout
                HStack(alignment: .top, spacing: 24) {
                    // Projects by Status
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Projects by Status")
                            .font(.headline)

                        ForEach(stats.projectsByStatus, id: \.0) { status, count in
                            HStack {
                                Circle()
                                    .fill(statusColor(status))
                                    .frame(width: 8, height: 8)
                                Text(status.displayName)
                                    .font(.subheadline)
                                Spacer()
                                Text("\(count)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(.background)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.05), radius: 2, y: 1)

                    // Team by Grade
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Team by Grade")
                            .font(.headline)

                        ForEach(stats.membersByGrade, id: \.0) { grade, count in
                            HStack {
                                Text(grade.displayName)
                                    .font(.subheadline)
                                Spacer()
                                Text("\(count)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(.background)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.05), radius: 2, y: 1)

                    // Recent AI Insights
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent AI Insights")
                            .font(.headline)

                        if recentInsights.isEmpty {
                            Text("No insights yet. Run AI analysis to generate insights.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(recentInsights.prefix(5)) { insight in
                                HStack(spacing: 8) {
                                    Image(systemName: insight.insightType.icon)
                                        .foregroundStyle(.orange)
                                        .frame(width: 20)
                                    VStack(alignment: .leading) {
                                        Text(insight.title)
                                            .font(.subheadline)
                                            .lineLimit(1)
                                        Text(insight.content)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .background(.background)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                }
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { loadData() }
    }

    private func loadData() {
        do {
            stats = try appState.database.read { db in
                var s = DashboardStats()
                s.activeMembers = try Member.filter(Member.Columns.status == "active").fetchCount(db)
                s.activeProjects = try Project.filter(Project.Columns.status == "active").fetchCount(db)
                s.activeClients = try Client.filter(Client.Columns.relationshipStatus == "active").fetchCount(db)
                s.pendingInsights = try AIInsight.filter(AIInsight.Columns.isDismissed == false).fetchCount(db)

                // Projects by status
                for status in ProjectStatus.allCases {
                    let count = try Project.filter(Project.Columns.status == status.rawValue).fetchCount(db)
                    if count > 0 {
                        s.projectsByStatus.append((status, count))
                    }
                }

                // Members by grade
                for grade in Grade.allCases {
                    let count = try Member
                        .filter(Member.Columns.grade == grade.rawValue)
                        .filter(Member.Columns.status == "active")
                        .fetchCount(db)
                    if count > 0 {
                        s.membersByGrade.append((grade, count))
                    }
                }

                return s
            }

            recentInsights = try appState.database.read { db in
                try AIInsight
                    .filter(AIInsight.Columns.isDismissed == false)
                    .order(AIInsight.Columns.createdAt.desc)
                    .limit(5)
                    .fetchAll(db)
            }
        } catch {
            print("Dashboard load error: \(error)")
        }
    }

    private func statusColor(_ status: ProjectStatus) -> Color {
        switch status {
        case .discovery: return .purple
        case .proposal: return .blue
        case .active: return .green
        case .onHold: return .orange
        case .completed: return .gray
        case .cancelled: return .red
        }
    }
}

struct DashboardStats {
    var activeMembers = 0
    var activeProjects = 0
    var activeClients = 0
    var pendingInsights = 0
    var projectsByStatus: [(ProjectStatus, Int)] = []
    var membersByGrade: [(Grade, Int)] = []
}

// MARK: - Stat Card
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                Spacer()
            }
            Text(value)
                .font(.system(size: 36, weight: .bold, design: .rounded))
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }
}
