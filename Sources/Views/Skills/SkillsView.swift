import SwiftUI
import GRDB

struct SkillsView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("", selection: $selectedTab) {
                Text("Skills List").tag(0)
                Text("Skills Matrix").tag(1)
            }
            .pickerStyle(.segmented)
            .frame(width: 280)
            .padding(.top, 16)
            .padding(.bottom, 8)

            if selectedTab == 0 {
                SkillsListView()
            } else {
                SkillsMatrixView()
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - Skills List View

struct SkillsListView: View {
    @EnvironmentObject var appState: AppState
    @State private var skills: [Skill] = []
    @State private var selectedSkill: Skill?
    @State private var selectedCategory: SkillCategory?
    @State private var searchText = ""
    @State private var memberSkillMap: [Int64: [(Member, Int)]] = [:] // skillId -> [(member, proficiency)]
    @State private var levelDefsMap: [Int64: [SkillLevelDefinition]] = [:] // skillId -> level defs

    private var filteredSkills: [Skill] {
        var result = skills
        if let cat = selectedCategory {
            result = result.filter { $0.category == cat }
        }
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                ($0.description ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
        return result
    }

    private var groupedSkills: [(SkillCategory, [Skill])] {
        let grouped = Dictionary(grouping: filteredSkills) { $0.category }
        return SkillCategory.allCases.compactMap { cat in
            guard let items = grouped[cat], !items.isEmpty else { return nil }
            return (cat, items)
        }
    }

    var body: some View {
        HSplitView {
            // Left: skill list
            VStack(alignment: .leading, spacing: 0) {
                // Search & filter
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Search skills...", text: $searchText)
                            .textFieldStyle(.plain)
                    }
                    .padding(8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

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
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider()

                // Skill list
                List(selection: $selectedSkill) {
                    ForEach(groupedSkills, id: \.0) { category, categorySkills in
                        Section {
                            ForEach(categorySkills) { skill in
                                SkillRowView(
                                    skill: skill,
                                    memberCount: memberSkillMap[skill.id ?? 0]?.count ?? 0
                                )
                                .tag(skill)
                            }
                        } header: {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(categoryColor(category))
                                    .frame(width: 8, height: 8)
                                Text(category.displayName)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                Text("(\(categorySkills.count))")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
            }
            .frame(minWidth: 260, idealWidth: 300, maxWidth: 400)

            // Right: detail
            if let skill = selectedSkill {
                SkillDetailView(
                    skill: skill,
                    members: memberSkillMap[skill.id ?? 0] ?? [],
                    levelDefinitions: levelDefsMap[skill.id ?? 0] ?? []
                )
            } else {
                ContentUnavailableView(
                    "Select a Skill",
                    systemImage: "star",
                    description: Text("Choose a skill from the list to see details")
                )
            }
        }
        .onAppear { loadData() }
    }

    private func loadData() {
        do {
            skills = try appState.database.read { db in
                try Skill.order(Skill.Columns.category, Skill.Columns.name).fetchAll(db)
            }
            let members = try appState.database.read { db in
                try Member.order(Member.Columns.name).fetchAll(db)
            }
            let memberMap = Dictionary(uniqueKeysWithValues: members.compactMap { m in
                m.id.map { ($0, m) }
            })
            let allMemberSkills = try appState.database.read { db in
                try MemberSkill.fetchAll(db)
            }

            var map: [Int64: [(Member, Int)]] = [:]
            for ms in allMemberSkills {
                guard let member = memberMap[ms.memberId] else { continue }
                map[ms.skillId, default: []].append((member, ms.proficiency))
            }
            // Sort each skill's members by proficiency desc
            for key in map.keys {
                map[key]?.sort { $0.1 > $1.1 }
            }
            memberSkillMap = map

            let allLevelDefs = try appState.database.read { db in
                try SkillLevelDefinition
                    .order(SkillLevelDefinition.Columns.skillId, SkillLevelDefinition.Columns.level)
                    .fetchAll(db)
            }
            levelDefsMap = Dictionary(grouping: allLevelDefs) { $0.skillId }

            if selectedSkill == nil, let first = skills.first {
                selectedSkill = first
            }
        } catch {
            print("Load skills error: \(error)")
        }
    }

    private func categoryColor(_ cat: SkillCategory) -> Color {
        switch cat {
        case .design: return .purple
        case .tech: return .blue
        case .business: return .green
        case .research: return .orange
        }
    }
}

// MARK: - Skill Row

struct SkillRowView: View {
    let skill: Skill
    let memberCount: Int

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: skillIcon)
                .font(.body)
                .foregroundStyle(categoryColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(skill.name)
                    .font(.body)
                    .lineLimit(1)
                if let desc = skill.description, !desc.isEmpty {
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if memberCount > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "person.fill")
                        .font(.caption2)
                    Text("\(memberCount)")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var categoryColor: Color {
        switch skill.category {
        case .design: return .purple
        case .tech: return .blue
        case .business: return .green
        case .research: return .orange
        }
    }

    private var skillIcon: String {
        switch skill.category {
        case .design: return "paintbrush"
        case .tech: return "chevron.left.forwardslash.chevron.right"
        case .business: return "briefcase"
        case .research: return "magnifyingglass.circle"
        }
    }
}

// MARK: - Skill Detail

struct SkillDetailView: View {
    let skill: Skill
    let members: [(Member, Int)]
    let levelDefinitions: [SkillLevelDefinition]

    private var avgProficiency: Double {
        guard !members.isEmpty else { return 0 }
        return Double(members.reduce(0) { $0 + $1.1 }) / Double(members.count)
    }

    private var proficiencyDistribution: [(Int, Int)] {
        var dist = [Int: Int]()
        for (_, level) in members {
            dist[level, default: 0] += 1
        }
        return (1...5).map { ($0, dist[$0] ?? 0) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Image(systemName: skillIcon)
                            .font(.title2)
                            .foregroundStyle(categoryColor)
                        Text(skill.name)
                            .font(.title2)
                            .fontWeight(.bold)
                    }

                    HStack(spacing: 12) {
                        StatusBadge(status: skill.category.displayName, color: categoryColor)
                        if !members.isEmpty {
                            Text("\(members.count) members")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let desc = skill.description, !desc.isEmpty {
                        Text(desc)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .lineSpacing(4)
                            .padding(.top, 4)
                    }
                }

                // Level definitions
                if !levelDefinitions.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Level Definitions")
                            .font(.headline)

                        VStack(spacing: 8) {
                            ForEach(levelDefinitions.sorted(by: { $0.level < $1.level })) { def in
                                let countAtLevel = members.filter { $0.1 == def.level }.count
                                HStack(spacing: 0) {
                                    // Level badge
                                    ZStack {
                                        levelColor(def.level).opacity(0.12)
                                        VStack(spacing: 2) {
                                            Text("Lv.\(def.level)")
                                                .font(.caption2)
                                                .fontWeight(.bold)
                                                .foregroundStyle(levelColor(def.level))
                                            Text(def.title)
                                                .font(.caption2)
                                                .fontWeight(.medium)
                                                .foregroundStyle(levelColor(def.level))
                                        }
                                    }
                                    .frame(width: 72)

                                    // Description
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(def.levelDescription)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineSpacing(3)

                                        if countAtLevel > 0 {
                                            HStack(spacing: 3) {
                                                Image(systemName: "person.fill")
                                                    .font(.system(size: 8))
                                                Text("\(countAtLevel)")
                                                    .font(.caption2)
                                                    .fontWeight(.medium)
                                            }
                                            .foregroundStyle(levelColor(def.level))
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .background(Color(nsColor: .controlBackgroundColor))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }

                if !members.isEmpty {
                    Divider()

                    // Stats
                    HStack(spacing: 24) {
                        StatBox(title: "Members", value: "\(members.count)", icon: "person.3")
                        StatBox(title: "Avg Proficiency", value: String(format: "%.1f", avgProficiency), icon: "chart.bar")
                        StatBox(
                            title: "Expert (Lv.5)",
                            value: "\(members.filter { $0.1 == 5 }.count)",
                            icon: "star.fill"
                        )
                    }

                    Divider()

                    // Proficiency distribution
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Proficiency Distribution")
                            .font(.headline)

                        HStack(alignment: .bottom, spacing: 12) {
                            ForEach(proficiencyDistribution, id: \.0) { level, count in
                                VStack(spacing: 4) {
                                    Text("\(count)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(levelColor(level).opacity(0.8))
                                        .frame(width: 36, height: max(4, CGFloat(count) * 16))
                                    Text("Lv.\(level)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                    }

                    Divider()

                    // Member list
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Members with this skill")
                            .font(.headline)

                        ForEach(members, id: \.0.id) { member, proficiency in
                            HStack(spacing: 10) {
                                AvatarView(name: member.name, size: 30, avatarUrl: member.avatarUrl)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(member.name)
                                        .font(.body)
                                    HStack(spacing: 6) {
                                        Text(member.grade.displayName)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        if let def = levelDefinitions.first(where: { $0.level == proficiency }) {
                                            Text("· \(def.title)")
                                                .font(.caption)
                                                .foregroundStyle(levelColor(proficiency))
                                        }
                                    }
                                }

                                Spacer()

                                ProficiencyDots(level: proficiency)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } else {
                    Divider()
                    ContentUnavailableView(
                        "No Members",
                        systemImage: "person.slash",
                        description: Text("No members have been assigned this skill yet")
                    )
                }
            }
            .padding(24)
        }
    }

    private func levelColor(_ level: Int) -> Color {
        switch level {
        case 1: return .gray
        case 2: return .blue
        case 3: return .cyan
        case 4: return .orange
        case 5: return .purple
        default: return .gray
        }
    }

    private var categoryColor: Color {
        switch skill.category {
        case .design: return .purple
        case .tech: return .blue
        case .business: return .green
        case .research: return .orange
        }
    }

    private var skillIcon: String {
        switch skill.category {
        case .design: return "paintbrush"
        case .tech: return "chevron.left.forwardslash.chevron.right"
        case .business: return "briefcase"
        case .research: return "magnifyingglass.circle"
        }
    }
}

// MARK: - Stat Box

private struct StatBox: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
