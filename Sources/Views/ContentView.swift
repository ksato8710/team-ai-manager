import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selection: $appState.selectedSection)
        } detail: {
            detailView
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear {
            do {
                try SeedData.seedIfEmpty(db: appState.database)
            } catch {
                print("SEED ERROR: \(error)")
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch appState.selectedSection {
        case .dashboard:
            DashboardView()
        case .members:
            MembersView()
        case .projects:
            ProjectsView()
        case .clients:
            ClientsView()
        case .skills:
            SkillsView()
        case .knowledge:
            KnowledgeView()
        case .aiInsights:
            AIInsightsView()
        case .scanners:
            ScannersView()
        case .projectPlanning:
            ProjectPlanningView()
        case .assignmentAnalysis:
            ToolPlaceholderView(
                title: "Assignment Analysis",
                icon: "person.crop.rectangle.stack",
                description: "メンバーの稼働状況とスキルに基づくアサイン見通し分析。プロジェクト間のリソース配分を最適化します。"
            )
        case .companyAnalysis:
            ToolPlaceholderView(
                title: "Company Analysis",
                icon: "chart.bar.xaxis",
                description: "全社プロジェクトの横断分析。稼働率、スキル分布、リスクの全体像を可視化します。"
            )
        case .docAbout:
            DocAboutView()
        case .docDataModel:
            DocDataModelView()
        }
    }
}

// MARK: - Sidebar
struct SidebarView: View {
    @Binding var selection: SidebarSection

    var body: some View {
        List(selection: $selection) {
            Section("Overview") {
                sidebarItem(.dashboard)
            }

            Section("Organization") {
                sidebarItem(.members)
                sidebarItem(.projects)
                sidebarItem(.clients)
            }

            Section("Growth") {
                sidebarItem(.skills)
                sidebarItem(.knowledge)
            }

            Section("Intelligence") {
                sidebarItem(.aiInsights)
                sidebarItem(.scanners)
            }

            Section("Tools") {
                sidebarItem(.projectPlanning)
                sidebarItem(.assignmentAnalysis)
                sidebarItem(.companyAnalysis)
            }

            Section("Doc") {
                sidebarItem(.docAbout)
                sidebarItem(.docDataModel)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Team AI Manager")
        .frame(minWidth: 200)
    }

    private func sidebarItem(_ section: SidebarSection) -> some View {
        Label(section.rawValue, systemImage: section.icon)
            .tag(section)
    }
}

// MARK: - Tool Placeholder
struct ToolPlaceholderView: View {
    let title: String
    let icon: String
    let description: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
            Text(description)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
            Text("Coming Soon")
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.15))
                .foregroundStyle(.orange)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
