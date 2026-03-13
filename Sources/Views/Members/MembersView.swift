import SwiftUI
import GRDB

struct MembersView: View {
    @EnvironmentObject var appState: AppState
    @State private var members: [Member] = []
    @State private var roles: [Int64: Role] = [:]
    @State private var searchText = ""
    @State private var selectedGrade: Grade?
    @State private var selectedMember: Member?
    @State private var showingAddSheet = false

    var filteredMembers: [Member] {
        members.filter { member in
            let matchesSearch = searchText.isEmpty ||
                member.name.localizedCaseInsensitiveContains(searchText) ||
                member.email.localizedCaseInsensitiveContains(searchText)
            let matchesGrade = selectedGrade == nil || member.grade == selectedGrade
            return matchesSearch && matchesGrade
        }
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                // Toolbar
                HStack {
                    Text("Members")
                        .font(.title2)
                        .fontWeight(.bold)
                    Spacer()
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
                .padding(.horizontal)
                .padding(.top, 12)

                // Search & Filter
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search members...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal)
                .padding(.top, 8)

                // Grade filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        FilterChip(title: "All", isSelected: selectedGrade == nil) {
                            selectedGrade = nil
                        }
                        ForEach(Grade.allCases, id: \.self) { grade in
                            FilterChip(title: grade.displayName, isSelected: selectedGrade == grade) {
                                selectedGrade = selectedGrade == grade ? nil : grade
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)

                // Member List
                List(filteredMembers, selection: $selectedMember) { member in
                    MemberRow(member: member, role: roles[member.roleId ?? 0])
                        .tag(member)
                }
                .listStyle(.inset)
            }
            .frame(minWidth: 300)
        } detail: {
            if let member = selectedMember {
                MemberDetailView(member: member, role: roles[member.roleId ?? 0], onMemberUpdated: loadData)
            } else {
                ContentUnavailableView("Select a Member", systemImage: "person", description: Text("Choose a member from the list to view details"))
            }
        }
        .onAppear { loadData() }
        .sheet(isPresented: $showingAddSheet) {
            AddMemberSheet(roles: Array(roles.values)) { newMember in
                var member = newMember
                try? appState.database.write { db in
                    try member.insert(db)
                }
                loadData()
            }
        }
    }

    private func loadData() {
        do {
            members = try appState.database.read { db in
                try Member.order(Member.Columns.grade.desc, Member.Columns.name).fetchAll(db)
            }
            let roleList = try appState.database.read { db in
                try Role.fetchAll(db)
            }
            roles = Dictionary(uniqueKeysWithValues: roleList.compactMap { role in
                role.id.map { ($0, role) }
            })
        } catch {
            print("Load members error: \(error)")
        }
    }
}

// MARK: - Member Row
struct MemberRow: View {
    let member: Member
    let role: Role?

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(name: member.name, size: 40, avatarUrl: member.avatarUrl)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(member.name)
                        .fontWeight(.medium)
                    GradeBadge(grade: member.grade)
                }
                if let role = role {
                    Text(role.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            StatusBadge(status: member.status.displayName, color: member.status == .active ? .green : .gray)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Member Detail
struct MemberDetailView: View {
    let member: Member
    let role: Role?
    var onMemberUpdated: (() -> Void)? = nil
    @EnvironmentObject var appState: AppState
    @State private var memberSkills: [(MemberSkill, Skill)] = []
    @State private var projectAssignments: [(ProjectMember, Project)] = []
    @State private var showingAvatarSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack(spacing: 16) {
                    AvatarView(name: member.name, size: 72, avatarUrl: member.avatarUrl)
                        .onTapGesture { showingAvatarSheet = true }
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.white, .blue)
                                .offset(x: 2, y: 2)
                        }
                        .help("Click to change avatar")
                    VStack(alignment: .leading, spacing: 4) {
                        Text(member.name)
                            .font(.title)
                            .fontWeight(.bold)
                        if let role = role {
                            Text(role.title)
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                        HStack(spacing: 8) {
                            GradeBadge(grade: member.grade)
                            StatusBadge(status: member.status.displayName, color: member.status == .active ? .green : .gray)
                        }
                    }
                    Spacer()
                }

                Divider()

                // Info
                if let bio = member.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    InfoItem(label: "Email", value: member.email)
                    InfoItem(label: "Capacity", value: "\(Int(member.weeklyCapacityHours))h/week")
                    if let joinDate = member.joinDate {
                        InfoItem(label: "Joined", value: joinDate)
                    }
                }

                // Skills
                if !memberSkills.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Skills")
                            .font(.headline)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))], spacing: 8) {
                            ForEach(memberSkills, id: \.0.id) { ms, skill in
                                HStack {
                                    Text(skill.name)
                                        .font(.subheadline)
                                    Spacer()
                                    ProficiencyDots(level: ms.proficiency)
                                }
                                .padding(8)
                                .background(Color(nsColor: .controlBackgroundColor))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                }

                // Project Assignments
                if !projectAssignments.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Active Projects")
                            .font(.headline)
                        ForEach(projectAssignments, id: \.1.id) { pm, project in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(project.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    if let role = pm.roleInProject {
                                        Text(role)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Text("\(pm.allocationPct)%")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.blue)
                            }
                            .padding(8)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
            }
            .padding(24)
        }
        .onAppear { loadMemberDetails() }
        .onChange(of: member) { loadMemberDetails() }
        .sheet(isPresented: $showingAvatarSheet) {
            AvatarEditSheet(member: member) {
                onMemberUpdated?()
            }
        }
    }

    private func loadMemberDetails() {
        guard let id = member.id else { return }
        do {
            memberSkills = try appState.database.read { db in
                let ms = try MemberSkill.filter(MemberSkill.Columns.memberId == id).fetchAll(db)
                return try ms.compactMap { memberSkill in
                    guard let skill = try Skill.fetchOne(db, id: memberSkill.skillId) else { return nil }
                    return (memberSkill, skill)
                }
            }
            projectAssignments = try appState.database.read { db in
                let pm = try ProjectMember
                    .filter(ProjectMember.Columns.memberId == id)
                    .filter(ProjectMember.Columns.isActive == true)
                    .fetchAll(db)
                return try pm.compactMap { assignment in
                    guard let project = try Project.fetchOne(db, id: assignment.projectId) else { return nil }
                    return (assignment, project)
                }
            }
        } catch {
            print("Load member details error: \(error)")
        }
    }
}

// MARK: - Add Member Sheet
struct AddMemberSheet: View {
    let roles: [Role]
    let onSave: (Member) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var email = ""
    @State private var selectedRoleId: Int64?
    @State private var grade: Grade = .ic

    var body: some View {
        VStack(spacing: 16) {
            Text("Add Member")
                .font(.title2)
                .fontWeight(.bold)

            Form {
                TextField("Name", text: $name)
                TextField("Email", text: $email)
                Picker("Role", selection: $selectedRoleId) {
                    Text("Select...").tag(nil as Int64?)
                    ForEach(roles, id: \.id) { role in
                        Text(role.title).tag(role.id as Int64?)
                    }
                }
                Picker("Grade", selection: $grade) {
                    ForEach(Grade.allCases, id: \.self) { g in
                        Text(g.displayName).tag(g)
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Add") {
                    let member = Member(
                        name: name, email: email,
                        roleId: selectedRoleId, grade: grade,
                        status: .active, weeklyCapacityHours: 40.0
                    )
                    onSave(member)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || email.isEmpty)
            }
            .padding(.horizontal)
        }
        .padding()
        .frame(width: 450, height: 350)
    }
}

// MARK: - Avatar Edit Sheet
struct AvatarEditSheet: View {
    let member: Member
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @State private var urlText: String = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Change Avatar")
                .font(.title3)
                .fontWeight(.bold)

            // Current avatar
            AvatarView(name: member.name, size: 80, avatarUrl: member.avatarUrl)

            // URL input
            VStack(alignment: .leading, spacing: 6) {
                Text("Image URL")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("https://example.com/avatar.jpg", text: $urlText)
                    .textFieldStyle(.roundedBorder)
            }

            // Preview
            if !urlText.isEmpty, let url = URL(string: urlText) {
                VStack(spacing: 6) {
                    Text("Preview")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                        case .failure:
                            VStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundStyle(.orange)
                                Text("Failed to load")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 80, height: 80)
                        default:
                            ProgressView()
                                .frame(width: 80, height: 80)
                        }
                    }
                }
            }

            Spacer()

            HStack {
                if member.avatarUrl != nil {
                    Button("Remove Avatar") {
                        saveAvatar(nil)
                    }
                    .foregroundStyle(.red)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    saveAvatar(urlText.isEmpty ? nil : urlText)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(urlText.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 400, height: 420)
        .onAppear {
            urlText = member.avatarUrl ?? ""
        }
    }

    private func saveAvatar(_ url: String?) {
        guard let memberId = member.id else { return }
        do {
            try appState.database.write { db in
                try db.execute(
                    sql: "UPDATE members SET avatar_url = ?, updated_at = datetime('now') WHERE id = ?",
                    arguments: [url, memberId]
                )
            }
            onSave()
            dismiss()
        } catch {
            print("Save avatar error: \(error)")
        }
    }
}

// MARK: - Info Item
struct InfoItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.subheadline)
        }
    }
}
