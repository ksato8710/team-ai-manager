import SwiftUI
import GRDB

struct SkillsMatrixView: View {
    @EnvironmentObject var appState: AppState
    @State private var skills: [Skill] = []
    @State private var members: [Member] = []
    @State private var matrix: [Int64: [Int64: Int]] = [:] // memberId -> skillId -> proficiency
    @State private var selectedCategory: SkillCategory?

    var filteredSkills: [Skill] {
        if let cat = selectedCategory {
            return skills.filter { $0.category == cat }
        }
        return skills
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Skills Matrix")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Text("\(members.count) members, \(skills.count) skills")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            // Category filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    FilterChip(title: "All", isSelected: selectedCategory == nil) {
                        selectedCategory = nil
                    }
                    ForEach(SkillCategory.allCases, id: \.self) { cat in
                        FilterChip(title: cat.displayName, isSelected: selectedCategory == cat) {
                            selectedCategory = selectedCategory == cat ? nil : cat
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
            .padding(.vertical, 12)

            // Matrix
            if filteredSkills.isEmpty || members.isEmpty {
                ContentUnavailableView("No Data", systemImage: "star", description: Text("Add skills and assign them to members"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView([.horizontal, .vertical]) {
                    VStack(alignment: .leading, spacing: 0) {
                        // Header row
                        HStack(spacing: 0) {
                            Text("Member")
                                .font(.caption)
                                .fontWeight(.bold)
                                .frame(width: 160, alignment: .leading)
                                .padding(8)

                            ForEach(filteredSkills) { skill in
                                Text(skill.name)
                                    .font(.caption2)
                                    .rotationEffect(.degrees(-45))
                                    .frame(width: 48, height: 60)
                            }
                        }
                        .background(Color(nsColor: .controlBackgroundColor))

                        Divider()

                        // Data rows
                        ForEach(members) { member in
                            HStack(spacing: 0) {
                                HStack(spacing: 6) {
                                    AvatarView(name: member.name, size: 24, avatarUrl: member.avatarUrl)
                                    Text(member.name)
                                        .font(.caption)
                                        .lineLimit(1)
                                }
                                .frame(width: 160, alignment: .leading)
                                .padding(8)

                                ForEach(filteredSkills) { skill in
                                    let level = matrix[member.id ?? 0]?[skill.id ?? 0] ?? 0
                                    SkillCell(level: level)
                                        .frame(width: 48, height: 36)
                                }
                            }

                            Divider()
                        }
                    }
                }
                .padding(24)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { loadData() }
    }

    private func loadData() {
        do {
            skills = try appState.database.read { db in
                try Skill.order(Skill.Columns.category, Skill.Columns.name).fetchAll(db)
            }
            members = try appState.database.read { db in
                try Member
                    .filter(Member.Columns.status == "active")
                    .order(Member.Columns.grade.desc, Member.Columns.name)
                    .fetchAll(db)
            }
            let allMemberSkills = try appState.database.read { db in
                try MemberSkill.fetchAll(db)
            }
            matrix = [:]
            for ms in allMemberSkills {
                if matrix[ms.memberId] == nil {
                    matrix[ms.memberId] = [:]
                }
                matrix[ms.memberId]![ms.skillId] = ms.proficiency
            }
        } catch {
            print("Load skills matrix error: \(error)")
        }
    }
}

struct SkillCell: View {
    let level: Int

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(cellColor)
            .padding(2)
            .overlay {
                if level > 0 {
                    Text("\(level)")
                        .font(.caption2)
                        .foregroundStyle(.white)
                }
            }
    }

    var cellColor: Color {
        switch level {
        case 0: return Color(nsColor: .controlBackgroundColor)
        case 1: return .blue.opacity(0.2)
        case 2: return .blue.opacity(0.4)
        case 3: return .blue.opacity(0.6)
        case 4: return .blue.opacity(0.8)
        case 5: return .blue
        default: return .clear
        }
    }
}
