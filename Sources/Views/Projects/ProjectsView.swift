import SwiftUI
import GRDB

struct ProjectsView: View {
    @EnvironmentObject var appState: AppState
    @State private var projects: [Project] = []
    @State private var clients: [Int64: Client] = [:]
    @State private var searchText = ""
    @State private var selectedStatus: ProjectStatus?
    @State private var selectedProject: Project?
    @State private var showingAddSheet = false

    var filteredProjects: [Project] {
        projects.filter { project in
            let matchesSearch = searchText.isEmpty ||
                project.name.localizedCaseInsensitiveContains(searchText)
            let matchesStatus = selectedStatus == nil || project.status == selectedStatus
            return matchesSearch && matchesStatus
        }
    }

    var groupedProjects: [(ProjectStatus, [Project])] {
        let grouped = Dictionary(grouping: filteredProjects, by: \.status)
        return ProjectStatus.allCases.compactMap { status in
            guard let projects = grouped[status], !projects.isEmpty else { return nil }
            return (status, projects)
        }
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                HStack {
                    Text("Projects")
                        .font(.title2)
                        .fontWeight(.bold)
                    Spacer()
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
                .padding(.horizontal)
                .padding(.top, 12)

                // Search
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search projects...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal)
                .padding(.top, 8)

                // Status filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        FilterChip(title: "All", isSelected: selectedStatus == nil) {
                            selectedStatus = nil
                        }
                        ForEach(ProjectStatus.allCases, id: \.self) { status in
                            FilterChip(title: status.displayName, isSelected: selectedStatus == status) {
                                selectedStatus = selectedStatus == status ? nil : status
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)

                // Grouped list
                List(selection: $selectedProject) {
                    ForEach(groupedProjects, id: \.0) { status, projects in
                        Section {
                            ForEach(projects) { project in
                                ProjectRow(project: project, client: clients[project.clientId ?? 0])
                                    .tag(project)
                            }
                        } header: {
                            HStack {
                                Circle()
                                    .fill(statusColor(status))
                                    .frame(width: 8, height: 8)
                                Text(status.displayName)
                                Text("(\(projects.count))")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
            .navigationSplitViewColumnWidth(min: 300, ideal: 340, max: 450)
        } detail: {
            if let project = selectedProject {
                ProjectDetailView(project: project, client: clients[project.clientId ?? 0])
            } else {
                ContentUnavailableView("Select a Project", systemImage: "folder", description: Text("Choose a project from the list to view details"))
            }
        }
        .onAppear { loadData() }
        .sheet(isPresented: $showingAddSheet) {
            AddProjectSheet(clients: Array(clients.values)) { newProject in
                var project = newProject
                try? appState.database.write { db in
                    try project.insert(db)
                }
                loadData()
            }
        }
    }

    private func loadData() {
        do {
            projects = try appState.database.read { db in
                try Project.order(Project.Columns.status, Project.Columns.name).fetchAll(db)
            }
            let clientList = try appState.database.read { db in
                try Client.fetchAll(db)
            }
            clients = Dictionary(uniqueKeysWithValues: clientList.compactMap { c in
                c.id.map { ($0, c) }
            })
        } catch {
            print("Load projects error: \(error)")
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

struct ProjectRow: View {
    let project: Project
    let client: Client?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(project.name)
                .fontWeight(.medium)
            HStack(spacing: 8) {
                if let client = client {
                    Text(client.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(project.serviceType.displayName)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                if let phase = project.phase {
                    Text(phase.displayName)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct ProjectDetailView: View {
    let project: Project
    let client: Client?
    @EnvironmentObject var appState: AppState
    /// (ProjectMember, Member, effectiveAllocationPct for current month)
    @State private var assignedMembers: [(ProjectMember, Member, Int)] = []
    @State private var totalAllocations: [Int64: Int] = [:]

    private var projectTotalAllocation: Int {
        assignedMembers.reduce(0) { $0 + $1.2 }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(project.name)
                        .font(.title)
                        .fontWeight(.bold)
                    HStack(spacing: 8) {
                        StatusBadge(status: project.status.displayName, color: statusColor(project.status))
                        if let phase = project.phase {
                            StatusBadge(status: phase.displayName, color: .purple)
                        }
                        Text(project.serviceType.displayName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }

                if let client = client {
                    HStack {
                        Image(systemName: "building.2")
                            .foregroundStyle(.secondary)
                        Text(client.name)
                            .font(.subheadline)
                    }
                }

                Divider()

                if let desc = project.description, !desc.isEmpty {
                    Text(desc)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                // Timeline
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    if let start = project.startDate {
                        InfoItem(label: "Start Date", value: start)
                    }
                    if let end = project.endDate {
                        InfoItem(label: "End Date", value: end)
                    }
                    if let hours = project.budgetHours {
                        InfoItem(label: "Budget", value: "\(Int(hours))h")
                    }
                }

                // Team
                VStack(alignment: .leading, spacing: 8) {
                    TeamStructureHeader(
                        memberCount: assignedMembers.count,
                        totalAllocation: projectTotalAllocation,
                        label: "体制"
                    )

                    if assignedMembers.isEmpty {
                        Text("メンバーが割り当てられていません")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(assignedMembers, id: \.1.id) { pm, member, effectivePct in
                            TeamMemberCard(
                                member: member,
                                roleInProject: pm.roleInProject,
                                allocationPct: effectivePct,
                                totalAllocationPct: totalAllocations[member.id ?? 0] ?? effectivePct
                            )
                        }
                    }
                }
            }
            .padding(24)
        }
        .onAppear { loadDetails() }
        .onChange(of: project) { loadDetails() }
    }

    private func loadDetails() {
        guard let id = project.id else { return }
        let month = ProjectMemberAllocation.currentYearMonth
        do {
            (assignedMembers, totalAllocations) = try appState.database.read { db in
                let pms = try ProjectMember
                    .filter(ProjectMember.Columns.projectId == id)
                    .filter(ProjectMember.Columns.isActive == true)
                    .fetchAll(db)
                let members = try pms.compactMap { assignment -> (ProjectMember, Member, Int)? in
                    guard let member = try Member.fetchOne(db, id: assignment.memberId) else { return nil }
                    let effectivePct = try TeamDataQuery.effectiveAllocation(db: db, pm: assignment, yearMonth: month)
                    return (assignment, member, effectivePct)
                }
                let sorted = members.sorted { a, b in
                    if a.1.grade.sortOrder != b.1.grade.sortOrder {
                        return a.1.grade.sortOrder > b.1.grade.sortOrder
                    }
                    return a.2 > b.2
                }
                let allocs = try TeamDataQuery.fetchTotalAllocations(db: db, yearMonth: month)
                return (sorted, allocs)
            }
        } catch {
            print("Load project details error: \(error)")
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

struct AddProjectSheet: View {
    let clients: [Client]
    let onSave: (Project) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var selectedClientId: Int64?
    @State private var serviceType: ServiceType = .digitalProductUx
    @State private var status: ProjectStatus = .discovery

    var body: some View {
        VStack(spacing: 16) {
            Text("Add Project")
                .font(.title2)
                .fontWeight(.bold)

            Form {
                TextField("Project Name", text: $name)
                Picker("Client", selection: $selectedClientId) {
                    Text("Select...").tag(nil as Int64?)
                    ForEach(clients, id: \.id) { client in
                        Text(client.name).tag(client.id as Int64?)
                    }
                }
                Picker("Service Type", selection: $serviceType) {
                    ForEach(ServiceType.allCases, id: \.self) { st in
                        Text(st.displayName).tag(st)
                    }
                }
                Picker("Status", selection: $status) {
                    ForEach(ProjectStatus.allCases, id: \.self) { s in
                        Text(s.displayName).tag(s)
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Add") {
                    let project = Project(
                        name: name, clientId: selectedClientId,
                        status: status, serviceType: serviceType
                    )
                    onSave(project)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty)
            }
            .padding(.horizontal)
        }
        .padding()
        .frame(width: 450, height: 380)
    }
}
