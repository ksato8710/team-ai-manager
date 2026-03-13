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
