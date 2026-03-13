import SwiftUI
import GRDB

struct DocDataModelView: View {
    @EnvironmentObject var appState: AppState
    @State private var stats = DataModelStats()
    @State private var selectedEntity: EntityDoc?

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                HStack {
                    Text("Data Model")
                        .font(.title2)
                        .fontWeight(.bold)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 12)

                Text("テーブル構造とリレーション")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 4)

                List(selection: $selectedEntity) {
                    Section("コアエンティティ") {
                        ForEach(EntityDoc.coreEntities) { entity in
                            EntityListRow(entity: entity, count: stats.counts[entity.tableName] ?? 0)
                                .tag(entity)
                        }
                    }
                    Section("リレーション（中間テーブル）") {
                        ForEach(EntityDoc.junctionEntities) { entity in
                            EntityListRow(entity: entity, count: stats.counts[entity.tableName] ?? 0)
                                .tag(entity)
                        }
                    }
                    Section("システム") {
                        ForEach(EntityDoc.systemEntities) { entity in
                            EntityListRow(entity: entity, count: stats.counts[entity.tableName] ?? 0)
                                .tag(entity)
                        }
                    }
                }
                .listStyle(.inset)
            }
            .frame(minWidth: 280)
        } detail: {
            if let entity = selectedEntity {
                EntityDetailDoc(entity: entity, count: stats.counts[entity.tableName] ?? 0)
            } else {
                DataModelOverview(stats: stats)
            }
        }
        .onAppear { loadStats() }
    }

    private func loadStats() {
        do {
            stats = try appState.database.read { db in
                var s = DataModelStats()
                let tables = ["members", "projects", "clients", "roles", "skills",
                              "knowledge", "member_skills", "project_members",
                              "scan_sources", "activity_logs", "ai_insights"]
                for table in tables {
                    let count = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM \(table)") ?? 0
                    s.counts[table] = count
                }
                s.totalRecords = s.counts.values.reduce(0, +)
                return s
            }
        } catch {
            print("Data model stats error: \(error)")
        }
    }
}

struct DataModelStats {
    var counts: [String: Int] = [:]
    var totalRecords = 0
}

// MARK: - Overview (ER diagram style)

struct DataModelOverview: View {
    let stats: DataModelStats

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                Text("データモデル概要")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                // Stats bar
                HStack(spacing: 24) {
                    OverviewStat(value: "\(EntityDoc.allEntities.count)", label: "テーブル")
                    OverviewStat(value: "\(stats.totalRecords)", label: "レコード合計")
                    OverviewStat(value: "SQLite", label: "データベース")
                    OverviewStat(value: "GRDB.swift", label: "ORM")
                }

                Divider()

                // ER Diagram
                Text("エンティティリレーション図")
                    .font(.title3)
                    .fontWeight(.bold)

                ERDiagramView()

                Divider()

                // Data flow
                Text("データフロー")
                    .font(.title3)
                    .fontWeight(.bold)

                DataFlowDiagram()

                Divider()

                // Table summary
                Text("テーブル一覧")
                    .font(.title3)
                    .fontWeight(.bold)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(EntityDoc.allEntities) { entity in
                        TableSummaryCard(entity: entity, count: stats.counts[entity.tableName] ?? 0)
                    }
                }

                Spacer(minLength: 40)
            }
            .padding(32)
            .frame(maxWidth: 960)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct OverviewStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - ER Diagram (visual)

struct ERDiagramView: View {
    var body: some View {
        VStack(spacing: 0) {
            // Row 1: Core entities
            HStack(alignment: .top, spacing: 40) {
                erEntity("roles", "Roles", .blue, [
                    "id PK", "title", "department",
                ])
                VStack(spacing: 4) {
                    Spacer(minLength: 20)
                    erRelation("1", "N")
                }
                erEntity("members", "Members", .blue, [
                    "id PK", "name", "email",
                    "role_id FK → roles", "grade", "status",
                ])
                VStack(spacing: 4) {
                    Spacer(minLength: 20)
                    erRelation("N", "N")
                }
                erEntity("skills", "Skills", .orange, [
                    "id PK", "name", "category",
                ])
            }

            // Junction: member_skills
            HStack {
                Spacer()
                erJunction("member_skills", "Member Skills", [
                    "member_id FK", "skill_id FK", "proficiency 1-5",
                ])
                Spacer()
            }
            .padding(.vertical, 8)

            // Connector lines (visual)
            HStack(spacing: 80) {
                Spacer()
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 1, height: 20)
                Spacer()
            }

            // Row 2: Projects & Clients
            HStack(alignment: .top, spacing: 40) {
                erEntity("clients", "Clients", .purple, [
                    "id PK", "name", "industry",
                    "relationship_status",
                ])
                VStack(spacing: 4) {
                    Spacer(minLength: 20)
                    erRelation("1", "N")
                }
                erEntity("projects", "Projects", .green, [
                    "id PK", "name",
                    "client_id FK → clients",
                    "status", "phase", "service_type",
                ])
                VStack(spacing: 4) {
                    Spacer(minLength: 20)
                    erRelation("N", "N")
                }
                VStack(spacing: 8) {
                    Text("← Members")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    erJunction("project_members", "Project Members", [
                        "project_id FK", "member_id FK",
                        "role_in_project", "allocation_pct",
                    ])
                }
            }

            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 1, height: 20)

            // Row 3: Knowledge & AI
            HStack(alignment: .top, spacing: 40) {
                erEntity("knowledge", "Knowledge", .pink, [
                    "id PK", "title", "content",
                    "author_id FK → members",
                    "project_id FK → projects",
                ])
                erEntity("activity_logs", "Activity Logs", .teal, [
                    "id PK", "source_type",
                    "entity_type", "entity_id",
                    "raw_data", "processed_data",
                ])
                erEntity("ai_insights", "AI Insights", .indigo, [
                    "id PK", "entity_type", "entity_id",
                    "insight_type", "confidence",
                    "is_dismissed", "is_actioned",
                ])
            }

            // Row 4: Scan sources
            HStack {
                Spacer()
                erEntity("scan_sources", "Scan Sources", .teal, [
                    "id PK", "name", "source_type",
                    "config (JSON)", "status",
                    "last_scanned_at",
                ])
                Spacer()
            }
            .padding(.top, 8)
        }
        .padding(24)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func erEntity(_ table: String, _ title: String, _ color: Color, _ columns: [String]) -> some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(color.gradient)

            VStack(alignment: .leading, spacing: 2) {
                ForEach(columns, id: \.self) { col in
                    HStack(spacing: 4) {
                        if col.contains("PK") {
                            Image(systemName: "key.fill")
                                .font(.system(size: 7))
                                .foregroundStyle(.orange)
                        } else if col.contains("FK") {
                            Image(systemName: "link")
                                .font(.system(size: 7))
                                .foregroundStyle(.blue)
                        } else {
                            Circle()
                                .fill(.secondary.opacity(0.3))
                                .frame(width: 5, height: 5)
                        }
                        Text(col)
                            .font(.system(size: 10, design: .monospaced))
                    }
                }
            }
            .padding(8)
        }
        .frame(width: 180)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(color.opacity(0.4), lineWidth: 1)
        )
    }

    private func erJunction(_ table: String, _ title: String, _ columns: [String]) -> some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(Color.gray.gradient)

            VStack(alignment: .leading, spacing: 1) {
                ForEach(columns, id: \.self) { col in
                    Text(col)
                        .font(.system(size: 9, design: .monospaced))
                }
            }
            .padding(6)
        }
        .frame(width: 160)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.gray.opacity(0.4), lineWidth: 1)
        )
    }

    private func erRelation(_ left: String, _ right: String) -> some View {
        HStack(spacing: 4) {
            Text(left)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
            Rectangle()
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 30, height: 1)
            Text(right)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Data Flow Diagram

struct DataFlowDiagram: View {
    var body: some View {
        HStack(spacing: 0) {
            flowBlock("外部データソース", "Slack / GitHub\nFigma / Jira", "cloud.fill", .teal)
            flowConnector("スキャン")
            flowBlock("Scanner Plugin", "ScannerProtocol\n実装ごとに変換", "puzzlepiece.extension.fill", .blue)
            flowConnector("AI 変換")
            flowBlock("Activity Logs", "raw_data\n→ processed_data", "doc.text.fill", .orange)
            flowConnector("マッピング")
            flowBlock("データモデル", "Members / Projects\nSkills / Knowledge", "cylinder.split.1x2.fill", .green)
            flowConnector("分析")
            flowBlock("AI Insights", "推薦 / 警告\nスキルギャップ", "brain", .indigo)
        }
        .padding(20)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func flowBlock(_ title: String, _ desc: String, _ icon: String, _ color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            Text(desc)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(width: 120)
    }

    private func flowConnector(_ label: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 8))
                .foregroundStyle(.tertiary)
            Image(systemName: "arrow.right")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Entity List Row

struct EntityListRow: View {
    let entity: EntityDoc
    let count: Int

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: entity.icon)
                .foregroundStyle(entity.color)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(entity.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(entity.tableName)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .fontDesign(.monospaced)
            }
            Spacer()
            Text("\(count)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Entity Detail Doc

struct EntityDetailDoc: View {
    let entity: EntityDoc
    let count: Int

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack(spacing: 12) {
                    Image(systemName: entity.icon)
                        .font(.title)
                        .foregroundStyle(entity.color)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entity.displayName)
                            .font(.title)
                            .fontWeight(.bold)
                        Text(entity.tableName)
                            .font(.subheadline)
                            .fontDesign(.monospaced)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("\(count)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                        Text("レコード")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Description
                Text(entity.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)

                Divider()

                // Columns
                Text("カラム定義")
                    .font(.headline)

                VStack(spacing: 1) {
                    // Header row
                    HStack {
                        Text("カラム名")
                            .frame(width: 180, alignment: .leading)
                        Text("型")
                            .frame(width: 80, alignment: .leading)
                        Text("制約")
                            .frame(width: 120, alignment: .leading)
                        Text("説明")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(8)
                    .background(entity.color.opacity(0.1))

                    ForEach(entity.columns) { col in
                        HStack {
                            HStack(spacing: 4) {
                                if col.isPrimaryKey {
                                    Image(systemName: "key.fill")
                                        .font(.system(size: 8))
                                        .foregroundStyle(.orange)
                                } else if col.foreignKey != nil {
                                    Image(systemName: "link")
                                        .font(.system(size: 8))
                                        .foregroundStyle(.blue)
                                }
                                Text(col.name)
                                    .fontDesign(.monospaced)
                            }
                            .frame(width: 180, alignment: .leading)

                            Text(col.type)
                                .foregroundStyle(.secondary)
                                .frame(width: 80, alignment: .leading)

                            Text(col.constraints)
                                .foregroundStyle(.tertiary)
                                .frame(width: 120, alignment: .leading)

                            Text(col.description)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .font(.caption)
                        .padding(8)
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                )

                // Relationships
                if !entity.relationships.isEmpty {
                    Text("リレーション")
                        .font(.headline)

                    ForEach(entity.relationships, id: \.0) { rel in
                        HStack(spacing: 8) {
                            Text(rel.0)
                                .font(.caption)
                                .fontWeight(.medium)
                                .fontDesign(.monospaced)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                            Image(systemName: "arrow.right")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(rel.1)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Enum values
                if !entity.enumValues.isEmpty {
                    Text("定義値")
                        .font(.headline)

                    ForEach(entity.enumValues, id: \.0) { label, values in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(label)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            FlowLayout(spacing: 6) {
                                ForEach(values, id: \.self) { val in
                                    Text(val)
                                        .font(.caption2)
                                        .fontDesign(.monospaced)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(entity.color.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                            }
                        }
                    }
                }

                Spacer(minLength: 40)
            }
            .padding(24)
            .frame(maxWidth: 800)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}

// MARK: - Table Summary Card

struct TableSummaryCard: View {
    let entity: EntityDoc
    let count: Int

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: entity.icon)
                .font(.title3)
                .foregroundStyle(entity.color)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(entity.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("\(entity.columns.count) columns")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(count)")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(entity.color)
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Entity Documentation Data

struct ColumnDoc: Identifiable {
    let id = UUID()
    let name: String
    let type: String
    let constraints: String
    let description: String
    var isPrimaryKey: Bool = false
    var foreignKey: String? = nil
}

struct EntityDoc: Identifiable, Hashable {
    let id: String
    let tableName: String
    let displayName: String
    let description: String
    let icon: String
    let color: Color
    let columns: [ColumnDoc]
    let relationships: [(String, String)]
    let enumValues: [(String, [String])]

    static func == (lhs: EntityDoc, rhs: EntityDoc) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    static var allEntities: [EntityDoc] { coreEntities + junctionEntities + systemEntities }

    static let coreEntities: [EntityDoc] = [
        EntityDoc(
            id: "members", tableName: "members", displayName: "Members（メンバー）",
            description: "チームメンバーの情報を管理します。ロール（職種）とグレード（等級）を分離し、「Principal UX Designer」のような組み合わせを柔軟に表現します。スキルはmember_skills経由で多対多、プロジェクトはproject_members経由で多対多のリレーションを持ちます。",
            icon: "person.fill", color: .blue,
            columns: [
                ColumnDoc(name: "id", type: "INTEGER", constraints: "PK AUTO", description: "一意識別子", isPrimaryKey: true),
                ColumnDoc(name: "name", type: "TEXT", constraints: "NOT NULL", description: "氏名"),
                ColumnDoc(name: "email", type: "TEXT", constraints: "NOT NULL UNIQUE", description: "メールアドレス"),
                ColumnDoc(name: "role_id", type: "INTEGER", constraints: "FK → roles", description: "職種（ロール）", foreignKey: "roles"),
                ColumnDoc(name: "grade", type: "TEXT", constraints: "NOT NULL", description: "等級レベル"),
                ColumnDoc(name: "join_date", type: "TEXT", constraints: "", description: "入社日（ISO 8601）"),
                ColumnDoc(name: "avatar_url", type: "TEXT", constraints: "", description: "アバター画像URL"),
                ColumnDoc(name: "status", type: "TEXT", constraints: "NOT NULL", description: "在籍ステータス"),
                ColumnDoc(name: "bio", type: "TEXT", constraints: "", description: "自己紹介・経歴"),
                ColumnDoc(name: "specializations", type: "TEXT", constraints: "", description: "専門領域（JSON配列）"),
                ColumnDoc(name: "weekly_capacity_hours", type: "DOUBLE", constraints: "DEFAULT 40", description: "週間キャパシティ（時間）"),
            ],
            relationships: [
                ("roles → members", "1対N: 1つのロールに複数メンバー"),
                ("members ↔ skills", "N対N: member_skills 経由"),
                ("members ↔ projects", "N対N: project_members 経由"),
                ("members → knowledge", "1対N: メンバーがナレッジを作成"),
            ],
            enumValues: [
                ("grade", ["ic", "lead", "associate_principal", "principal", "executive_principal", "executive_officer"]),
                ("status", ["active", "on_leave", "offboarded"]),
            ]
        ),
        EntityDoc(
            id: "projects", tableName: "projects", displayName: "Projects（プロジェクト）",
            description: "クライアントから受託するプロジェクトを管理します。ステータス（全体状態）とフェーズ（現在の工程）を分けて管理し、サービスタイプでAlceoの5つのサービスラインに分類します。",
            icon: "folder.fill", color: .green,
            columns: [
                ColumnDoc(name: "id", type: "INTEGER", constraints: "PK AUTO", description: "一意識別子", isPrimaryKey: true),
                ColumnDoc(name: "name", type: "TEXT", constraints: "NOT NULL", description: "プロジェクト名"),
                ColumnDoc(name: "client_id", type: "INTEGER", constraints: "FK → clients", description: "クライアント", foreignKey: "clients"),
                ColumnDoc(name: "status", type: "TEXT", constraints: "NOT NULL", description: "全体ステータス"),
                ColumnDoc(name: "phase", type: "TEXT", constraints: "", description: "現在フェーズ"),
                ColumnDoc(name: "service_type", type: "TEXT", constraints: "NOT NULL", description: "サービスタイプ"),
                ColumnDoc(name: "description", type: "TEXT", constraints: "", description: "概要説明"),
                ColumnDoc(name: "start_date", type: "TEXT", constraints: "", description: "開始日"),
                ColumnDoc(name: "end_date", type: "TEXT", constraints: "", description: "終了予定日"),
                ColumnDoc(name: "budget_hours", type: "DOUBLE", constraints: "", description: "予算工数（時間）"),
            ],
            relationships: [
                ("clients → projects", "1対N: 1クライアントに複数プロジェクト"),
                ("projects ↔ members", "N対N: project_members 経由"),
            ],
            enumValues: [
                ("status", ["discovery", "proposal", "active", "on_hold", "completed", "cancelled"]),
                ("phase", ["research", "define", "ideate", "design", "develop", "test", "launch", "maintain"]),
                ("service_type", ["business_service_design", "digital_product_ux", "growth_design", "brand_design", "hr_development"]),
            ]
        ),
        EntityDoc(
            id: "clients", tableName: "clients", displayName: "Clients（クライアント）",
            description: "プロジェクトを発注するクライアント組織を管理します。業界分類とドメイン（専門領域）で分類し、関係ステータスで営業パイプラインも追跡できます。",
            icon: "building.2.fill", color: .purple,
            columns: [
                ColumnDoc(name: "id", type: "INTEGER", constraints: "PK AUTO", description: "一意識別子", isPrimaryKey: true),
                ColumnDoc(name: "name", type: "TEXT", constraints: "NOT NULL", description: "組織名"),
                ColumnDoc(name: "industry", type: "TEXT", constraints: "NOT NULL", description: "業界"),
                ColumnDoc(name: "domain", type: "TEXT", constraints: "", description: "専門ドメイン"),
                ColumnDoc(name: "contact_name", type: "TEXT", constraints: "", description: "担当者名"),
                ColumnDoc(name: "contact_email", type: "TEXT", constraints: "", description: "連絡先メール"),
                ColumnDoc(name: "relationship_status", type: "TEXT", constraints: "NOT NULL", description: "関係ステータス"),
                ColumnDoc(name: "website", type: "TEXT", constraints: "", description: "WebサイトURL"),
            ],
            relationships: [("clients → projects", "1対N: クライアントごとに複数プロジェクト")],
            enumValues: [
                ("industry", ["fintech", "government", "enterprise", "healthcare", "retail", "education", "other"]),
                ("relationship_status", ["prospect", "active", "inactive", "churned"]),
            ]
        ),
        EntityDoc(
            id: "roles", tableName: "roles", displayName: "Roles（ロール）",
            description: "チーム内の職種を定義します。グレード（等級）はメンバー側で管理し、ロールは純粋に職能を表します。これにより「Principal × UX Designer」のような組み合わせが可能です。",
            icon: "person.text.rectangle", color: .cyan,
            columns: [
                ColumnDoc(name: "id", type: "INTEGER", constraints: "PK AUTO", description: "一意識別子", isPrimaryKey: true),
                ColumnDoc(name: "title", type: "TEXT", constraints: "NOT NULL UNIQUE", description: "ロール名"),
                ColumnDoc(name: "description", type: "TEXT", constraints: "", description: "役割の説明"),
                ColumnDoc(name: "department", type: "TEXT", constraints: "", description: "所属部門"),
                ColumnDoc(name: "responsibilities", type: "TEXT", constraints: "", description: "責務一覧（JSON配列）"),
            ],
            relationships: [("roles → members", "1対N: 1ロールに複数メンバー")],
            enumValues: []
        ),
        EntityDoc(
            id: "skills", tableName: "skills", displayName: "Skills（スキル）",
            description: "組織で管理するスキルのカタログです。カテゴリで大分類し、member_skillsで各メンバーの熟練度（1-5）を追跡します。",
            icon: "star.fill", color: .orange,
            columns: [
                ColumnDoc(name: "id", type: "INTEGER", constraints: "PK AUTO", description: "一意識別子", isPrimaryKey: true),
                ColumnDoc(name: "name", type: "TEXT", constraints: "NOT NULL UNIQUE", description: "スキル名"),
                ColumnDoc(name: "category", type: "TEXT", constraints: "NOT NULL", description: "カテゴリ"),
                ColumnDoc(name: "description", type: "TEXT", constraints: "", description: "スキルの説明"),
            ],
            relationships: [("skills ↔ members", "N対N: member_skills 経由")],
            enumValues: [("category", ["design", "tech", "business", "research"])]
        ),
        EntityDoc(
            id: "knowledge", tableName: "knowledge", displayName: "Knowledge（ナレッジ）",
            description: "ケーススタディ、プロセス定義、ガイドライン、テンプレート、チーム原則など組織のナレッジベースです。Markdown形式のコンテンツを格納し、著者・プロジェクトへのリンクを持ちます。",
            icon: "book.fill", color: .pink,
            columns: [
                ColumnDoc(name: "id", type: "INTEGER", constraints: "PK AUTO", description: "一意識別子", isPrimaryKey: true),
                ColumnDoc(name: "title", type: "TEXT", constraints: "NOT NULL", description: "タイトル"),
                ColumnDoc(name: "content", type: "TEXT", constraints: "NOT NULL", description: "本文（Markdown）"),
                ColumnDoc(name: "category", type: "TEXT", constraints: "NOT NULL", description: "カテゴリ"),
                ColumnDoc(name: "author_id", type: "INTEGER", constraints: "FK → members", description: "著者", foreignKey: "members"),
                ColumnDoc(name: "project_id", type: "INTEGER", constraints: "FK → projects", description: "関連プロジェクト", foreignKey: "projects"),
                ColumnDoc(name: "is_published", type: "BOOLEAN", constraints: "NOT NULL", description: "公開/下書き"),
            ],
            relationships: [
                ("members → knowledge", "1対N: 著者"),
                ("projects → knowledge", "1対N: 関連プロジェクト（任意）"),
            ],
            enumValues: [("category", ["case_study", "process", "guideline", "template", "research_finding", "principle", "tutorial"])]
        ),
    ]

    static let junctionEntities: [EntityDoc] = [
        EntityDoc(
            id: "member_skills", tableName: "member_skills", displayName: "Member Skills（スキル割当）",
            description: "メンバーとスキルの多対多リレーションを管理する中間テーブルです。各メンバーの各スキルに対する熟練度（1: 初心者 〜 5: エキスパート）と最終評価日を記録します。",
            icon: "star.circle", color: .orange,
            columns: [
                ColumnDoc(name: "id", type: "INTEGER", constraints: "PK AUTO", description: "一意識別子", isPrimaryKey: true),
                ColumnDoc(name: "member_id", type: "INTEGER", constraints: "FK NOT NULL", description: "メンバー", foreignKey: "members"),
                ColumnDoc(name: "skill_id", type: "INTEGER", constraints: "FK NOT NULL", description: "スキル", foreignKey: "skills"),
                ColumnDoc(name: "proficiency", type: "INTEGER", constraints: "NOT NULL 1-5", description: "熟練度"),
                ColumnDoc(name: "last_assessed", type: "TEXT", constraints: "", description: "最終評価日"),
                ColumnDoc(name: "notes", type: "TEXT", constraints: "", description: "評価メモ"),
            ],
            relationships: [
                ("member_skills → members", "N対1"),
                ("member_skills → skills", "N対1"),
            ],
            enumValues: [("proficiency", ["1: Beginner", "2: Developing", "3: Proficient", "4: Advanced", "5: Expert"])]
        ),
        EntityDoc(
            id: "project_members", tableName: "project_members", displayName: "Project Members（アサイン）",
            description: "プロジェクトへのメンバーアサインを管理する中間テーブルです。プロジェクト内での役割と稼働率（%）を記録し、ワークロード管理の基盤となります。allocation_pctの合計が100%を超えるとAIが過負荷警告を出します。",
            icon: "person.badge.plus", color: .green,
            columns: [
                ColumnDoc(name: "id", type: "INTEGER", constraints: "PK AUTO", description: "一意識別子", isPrimaryKey: true),
                ColumnDoc(name: "project_id", type: "INTEGER", constraints: "FK NOT NULL", description: "プロジェクト", foreignKey: "projects"),
                ColumnDoc(name: "member_id", type: "INTEGER", constraints: "FK NOT NULL", description: "メンバー", foreignKey: "members"),
                ColumnDoc(name: "role_in_project", type: "TEXT", constraints: "", description: "プロジェクト内の役割"),
                ColumnDoc(name: "allocation_pct", type: "INTEGER", constraints: "DEFAULT 100", description: "稼働率 (0-100%)"),
                ColumnDoc(name: "start_date", type: "TEXT", constraints: "", description: "参画開始日"),
                ColumnDoc(name: "end_date", type: "TEXT", constraints: "", description: "参画終了日"),
                ColumnDoc(name: "is_active", type: "BOOLEAN", constraints: "NOT NULL", description: "現在アクティブか"),
            ],
            relationships: [
                ("project_members → projects", "N対1"),
                ("project_members → members", "N対1"),
            ],
            enumValues: []
        ),
    ]

    static let systemEntities: [EntityDoc] = [
        EntityDoc(
            id: "scan_sources", tableName: "scan_sources", displayName: "Scan Sources（スキャンソース）",
            description: "外部データソースの接続設定を管理します。各ソースタイプ（Slack、GitHub等）ごとにAPI設定をJSON形式で保持し、スキャン間隔やステータスを追跡します。",
            icon: "antenna.radiowaves.left.and.right", color: .teal,
            columns: [
                ColumnDoc(name: "id", type: "INTEGER", constraints: "PK AUTO", description: "一意識別子", isPrimaryKey: true),
                ColumnDoc(name: "name", type: "TEXT", constraints: "NOT NULL", description: "ソース名"),
                ColumnDoc(name: "source_type", type: "TEXT", constraints: "NOT NULL", description: "ソースタイプ"),
                ColumnDoc(name: "config", type: "TEXT", constraints: "NOT NULL", description: "設定（JSON）"),
                ColumnDoc(name: "status", type: "TEXT", constraints: "NOT NULL", description: "ステータス"),
                ColumnDoc(name: "scan_interval_minutes", type: "INTEGER", constraints: "DEFAULT 60", description: "スキャン間隔（分）"),
                ColumnDoc(name: "last_scanned_at", type: "TEXT", constraints: "", description: "最終スキャン日時"),
            ],
            relationships: [("scan_sources → activity_logs", "1対N: ソースごとに複数ログ")],
            enumValues: [
                ("source_type", ["figma", "github", "slack", "jira", "notion", "google_drive", "calendar", "manual"]),
                ("status", ["active", "paused", "error", "disabled"]),
            ]
        ),
        EntityDoc(
            id: "activity_logs", tableName: "activity_logs", displayName: "Activity Logs（活動ログ）",
            description: "スキャナーが取得した活動データを生データ（raw_data）と変換済みデータ（processed_data）の両方で保持します。entity_type + entity_idのポリモーフィック参照により、任意のエンティティに紐づけ可能です。",
            icon: "clock.arrow.circlepath", color: .teal,
            columns: [
                ColumnDoc(name: "id", type: "INTEGER", constraints: "PK AUTO", description: "一意識別子", isPrimaryKey: true),
                ColumnDoc(name: "scan_source_id", type: "INTEGER", constraints: "FK", description: "スキャンソース", foreignKey: "scan_sources"),
                ColumnDoc(name: "source_type", type: "TEXT", constraints: "NOT NULL", description: "ソースタイプ"),
                ColumnDoc(name: "entity_type", type: "TEXT", constraints: "NOT NULL", description: "対象エンティティ種別"),
                ColumnDoc(name: "entity_id", type: "INTEGER", constraints: "NOT NULL", description: "対象エンティティID"),
                ColumnDoc(name: "action", type: "TEXT", constraints: "", description: "アクション内容"),
                ColumnDoc(name: "raw_data", type: "TEXT", constraints: "", description: "生データ（JSON）"),
                ColumnDoc(name: "processed_data", type: "TEXT", constraints: "", description: "変換済みデータ（JSON）"),
                ColumnDoc(name: "occurred_at", type: "TEXT", constraints: "NOT NULL", description: "発生日時"),
            ],
            relationships: [("scan_sources → activity_logs", "N対1: ソースからの取得")],
            enumValues: [("entity_type", ["member", "project", "client", "knowledge"])]
        ),
        EntityDoc(
            id: "ai_insights", tableName: "ai_insights", displayName: "AI Insights（AIインサイト）",
            description: "AIが生成する分析結果・推薦・警告を格納します。各インサイトは対象エンティティへのポリモーフィック参照、信頼度スコア、対応ステータス（却下/アクション済み）を持ちます。",
            icon: "brain", color: .indigo,
            columns: [
                ColumnDoc(name: "id", type: "INTEGER", constraints: "PK AUTO", description: "一意識別子", isPrimaryKey: true),
                ColumnDoc(name: "entity_type", type: "TEXT", constraints: "NOT NULL", description: "対象種別"),
                ColumnDoc(name: "entity_id", type: "INTEGER", constraints: "", description: "対象ID（NULLでチーム全体）"),
                ColumnDoc(name: "insight_type", type: "TEXT", constraints: "NOT NULL", description: "インサイト種別"),
                ColumnDoc(name: "title", type: "TEXT", constraints: "NOT NULL", description: "タイトル"),
                ColumnDoc(name: "content", type: "TEXT", constraints: "NOT NULL", description: "詳細説明"),
                ColumnDoc(name: "confidence", type: "DOUBLE", constraints: "NOT NULL 0-1", description: "信頼度スコア"),
                ColumnDoc(name: "is_dismissed", type: "BOOLEAN", constraints: "NOT NULL", description: "却下済みフラグ"),
                ColumnDoc(name: "is_actioned", type: "BOOLEAN", constraints: "NOT NULL", description: "アクション済みフラグ"),
            ],
            relationships: [],
            enumValues: [
                ("insight_type", ["workload_alert", "skill_gap", "staffing_suggestion", "project_risk", "growth_opportunity", "collaboration_pattern", "knowledge_connection", "performance_trend"]),
                ("entity_type", ["member", "project", "client", "knowledge", "team"]),
            ]
        ),
    ]
}
