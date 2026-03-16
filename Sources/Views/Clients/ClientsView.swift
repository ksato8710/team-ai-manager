import SwiftUI
import GRDB

struct ClientsView: View {
    @EnvironmentObject var appState: AppState
    @State private var clients: [Client] = []
    @State private var projectCounts: [Int64: Int] = [:]
    @State private var searchText = ""
    @State private var selectedClient: Client?

    var filteredClients: [Client] {
        clients.filter { client in
            searchText.isEmpty || client.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                HStack {
                    Text("Clients")
                        .font(.title2)
                        .fontWeight(.bold)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 12)

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search clients...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal)
                .padding(.top, 8)

                List(filteredClients, selection: $selectedClient) { client in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(client.name)
                                .fontWeight(.medium)
                            HStack(spacing: 8) {
                                Text(client.industry.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let domain = client.domain {
                                    Text(domain)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.purple.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            StatusBadge(
                                status: client.relationshipStatus.displayName,
                                color: relationshipColor(client.relationshipStatus)
                            )
                            let count = projectCounts[client.id ?? 0] ?? 0
                            Text("\(count) project\(count == 1 ? "" : "s")")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    .tag(client)
                }
                .listStyle(.inset)
            }
            .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 420)
        } detail: {
            if let client = selectedClient {
                ClientDetailView(client: client)
            } else {
                ContentUnavailableView("Select a Client", systemImage: "building.2", description: Text("Choose a client from the list"))
            }
        }
        .onAppear { loadData() }
    }

    private func loadData() {
        do {
            clients = try appState.database.read { db in
                try Client.order(Client.Columns.name).fetchAll(db)
            }
            for client in clients {
                guard let id = client.id else { continue }
                projectCounts[id] = try appState.database.read { db in
                    try Project.filter(Project.Columns.clientId == id).fetchCount(db)
                }
            }
        } catch {
            print("Load clients error: \(error)")
        }
    }

    private func relationshipColor(_ status: RelationshipStatus) -> Color {
        switch status {
        case .prospect: return .blue
        case .active: return .green
        case .inactive: return .gray
        case .churned: return .red
        }
    }
}

struct ClientDetailView: View {
    let client: Client
    @EnvironmentObject var appState: AppState
    @State private var projects: [Project] = []
    @State private var selectedProject: Project?
    @State private var clientTeam: [(Member, [(Project, ProjectMember, Int)])] = []
    @State private var totalAllocations: [Int64: Int] = [:]
    @State private var showingSlackEdit = false
    @State private var slackChannelId = ""
    @State private var slackResult: SlackAnalysisResult?
    @State private var slackSyncing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(client.name)
                        .font(.title)
                        .fontWeight(.bold)
                    HStack(spacing: 8) {
                        StatusBadge(
                            status: client.relationshipStatus.displayName,
                            color: client.relationshipStatus == .active ? .green : .gray
                        )
                        Text(client.industry.displayName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }

                Divider()

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    if let domain = client.domain {
                        InfoItem(label: "Domain", value: domain)
                    }
                    if let contact = client.contactName {
                        InfoItem(label: "Contact", value: contact)
                    }
                    if let email = client.contactEmail {
                        InfoItem(label: "Email", value: email)
                    }
                    if let website = client.website {
                        InfoItem(label: "Website", value: website)
                    }
                }

                if let notes = client.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notes")
                            .font(.headline)
                        Text(notes)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }

                // Slack
                SlackSectionView(
                    channelId: client.slackChannelId,
                    isSyncing: slackSyncing,
                    result: slackResult,
                    onEdit: {
                        slackChannelId = client.slackChannelId ?? ""
                        showingSlackEdit = true
                    },
                    onSync: { syncSlack() }
                )

                Divider()

                // Team Structure
                if !clientTeam.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        TeamStructureHeader(
                            memberCount: clientTeam.count,
                            totalAllocation: clientTeam.reduce(0) { sum, item in
                                sum + item.1.reduce(0) { $0 + $1.2 }
                            },
                            label: "体制"
                        )

                        Text("\(clientTeam.count)名が \(projects.count) プロジェクトに参画中")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ForEach(clientTeam, id: \.0.id) { member, assignments in
                            ClientTeamMemberCard(
                                member: member,
                                assignments: assignments,
                                totalAllocationPct: totalAllocations[member.id ?? 0] ?? 0
                            )
                        }
                    }

                    Divider()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Projects (\(projects.count))")
                        .font(.headline)
                    ForEach(projects) { project in
                        Button {
                            selectedProject = project
                        } label: {
                            HStack {
                                Text(project.name)
                                    .font(.subheadline)
                                Spacer()
                                StatusBadge(status: project.status.displayName, color: projectStatusColor(project.status))
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(8)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(24)
        }
        .onAppear { loadProjects() }
        .onChange(of: client) { loadProjects() }
        .sheet(isPresented: $showingSlackEdit) {
            SlackChannelEditSheet(channelId: $slackChannelId) { newId in
                var updated = client
                updated.slackChannelId = newId.isEmpty ? nil : newId
                try? appState.database.write { db in try updated.update(db) }
            }
        }
        .sheet(item: $selectedProject) { project in
            ProjectDetailSheet(project: project, client: client)
                .environmentObject(appState)
        }
    }

    private func projectStatusColor(_ status: ProjectStatus) -> Color {
        switch status {
        case .discovery: return .purple
        case .proposal: return .blue
        case .active: return .green
        case .onHold: return .orange
        case .completed: return .gray
        case .cancelled: return .red
        }
    }

    private func syncSlack() {
        slackSyncing = true
        slackResult = nil
        Task {
            do {
                let result = try await appState.slackAgent.syncClient(client)
                slackResult = result
            } catch {
                slackResult = SlackAnalysisResult(
                    summary: "エラー: \(error.localizedDescription)",
                    statusUpdate: nil, keyTopics: [], actionItems: [], risks: []
                )
            }
            slackSyncing = false
        }
    }

    private func loadProjects() {
        guard let id = client.id else { return }
        do {
            projects = try appState.database.read { db in
                try Project.filter(Project.Columns.clientId == id).order(Project.Columns.status).fetchAll(db)
            }
            (clientTeam, totalAllocations) = try appState.database.read { db in
                let team = try TeamDataQuery.fetchClientTeam(db: db, clientId: id)
                let allocs = try TeamDataQuery.fetchTotalAllocations(db: db)
                return (team, allocs)
            }
        } catch {
            print("Load client projects error: \(error)")
        }
    }
}

// MARK: - Project Detail Sheet (shown from Clients view)

struct ProjectDetailSheet: View {
    let project: Project
    let client: Client?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(project.name)
                    .font(.headline)
                Spacer()
                Button("閉じる") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            ProjectDetailView(project: project, client: client)
        }
        .frame(width: 600, height: 500)
    }
}
