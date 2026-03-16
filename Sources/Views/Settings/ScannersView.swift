import SwiftUI

struct ScannersView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingAddSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Data Scanners")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Configure external data sources to automatically import team activity")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Run All Scans") {
                    Task {
                        await appState.scannerManager.runAllScans()
                    }
                }
                .buttonStyle(.bordered)
                .disabled(appState.scannerManager.isScanning)

                Button(action: { showingAddSheet = true }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(24)

            Divider()

            if appState.scannerManager.scanSources.isEmpty {
                ContentUnavailableView(
                    "No Scanners Configured",
                    systemImage: "antenna.radiowaves.left.and.right",
                    description: Text("Add data sources like Slack, GitHub, or Figma to start importing team activity automatically.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(appState.scannerManager.scanSources) { source in
                            ScanSourceCard(source: source)
                        }
                    }
                    .padding(24)
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $showingAddSheet) {
            AddScanSourceSheet { source in
                try? appState.scannerManager.addSource(source)
            }
        }
    }
}

struct ScanSourceCard: View {
    let source: ScanSource
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: source.sourceType.icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 44, height: 44)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(source.name)
                    .fontWeight(.medium)
                HStack(spacing: 8) {
                    Text(source.sourceType.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    StatusBadge(status: source.status.displayName, color: scanStatusColor(source.status))
                    if let last = source.lastScannedAt {
                        Text("Last: \(last)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                if let error = source.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(1)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button("Scan Now") {
                    Task {
                        try? await appState.scannerManager.runScan(for: source)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(role: .destructive) {
                    try? appState.scannerManager.deleteSource(source)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
            }
        }
        .padding(16)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }

    private func scanStatusColor(_ status: ScanSourceStatus) -> Color {
        switch status {
        case .active: return .green
        case .paused: return .orange
        case .error: return .red
        case .disabled: return .gray
        }
    }
}

struct AddScanSourceSheet: View {
    let onSave: (ScanSource) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var sourceType: ScanSourceType = .slack
    @State private var apiKey = ""
    @State private var workspaceId = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Add Data Source")
                .font(.title2)
                .fontWeight(.bold)

            Form {
                TextField("Name", text: $name)
                Picker("Source Type", selection: $sourceType) {
                    ForEach(ScanSourceType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                SecureField("API Key / Token", text: $apiKey)
                TextField("Workspace / Org ID", text: $workspaceId)
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Add") {
                    let config = ScannerConfig(
                        apiKey: apiKey.isEmpty ? nil : apiKey,
                        workspaceId: workspaceId.isEmpty ? nil : workspaceId
                    )
                    let configJSON = (try? JSONEncoder().encode(config)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
                    let source = ScanSource(
                        name: name,
                        sourceType: sourceType,
                        config: configJSON,
                        status: .active,
                        scanIntervalMinutes: 60
                    )
                    onSave(source)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty)
            }
            .padding(.horizontal)
        }
        .padding()
        .frame(width: 450, height: 350)
    }
}

// MARK: - Settings View
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            AISettingsView()
                .tabItem {
                    Label("AI", systemImage: "brain")
                }
        }
        .frame(width: 520, height: 400)
    }
}

struct GeneralSettingsView: View {
    @AppStorage("databasePath") private var databasePath = ""
    @State private var resyncMessage: String?
    @State private var isResyncing = false

    var body: some View {
        Form {
            Section("データベース") {
                Text("保存先: ~/Library/Application Support/TeamAIManager/")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("シードデータ同期") {
                Text("Data/organization/ 内の JSON ファイルを更新した場合、手動で再同期できます。プロジェクト憲章のデータは保持されます。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Button("シードデータを再同期") {
                        isResyncing = true
                        resyncMessage = nil
                        do {
                            try SeedData.forceResync(db: DatabaseManager.shared)
                            resyncMessage = "再同期が完了しました。アプリを再起動してください。"
                        } catch {
                            resyncMessage = "エラー: \(error.localizedDescription)"
                        }
                        isResyncing = false
                    }
                    .disabled(isResyncing)

                    if isResyncing {
                        ProgressView().scaleEffect(0.7)
                    }
                }

                if let message = resyncMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(message.hasPrefix("エラー") ? .red : .green)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct AISettingsView: View {
    @AppStorage("aiBackend") private var selectedBackend = AIBackend.claude.rawValue
    @State private var cliStatus: [AIBackend: Bool] = [:]

    private var backend: AIBackend {
        AIBackend(rawValue: selectedBackend) ?? .claude
    }

    var body: some View {
        Form {
            Section("AI Provider") {
                Picker("使用する AI CLI", selection: $selectedBackend) {
                    ForEach(AIBackend.allCases) { b in
                        Text(b.displayName).tag(b.rawValue)
                    }
                }
                .pickerStyle(.radioGroup)
                .onChange(of: selectedBackend) { _, newValue in
                    if let b = AIBackend(rawValue: newValue) {
                        AIBackend.current = b
                    }
                }

                ForEach(AIBackend.allCases) { b in
                    HStack {
                        Text(b.displayName)
                            .font(.subheadline)
                        Spacer()
                        if let available = cliStatus[b] {
                            if available {
                                Label("インストール済み", systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            } else {
                                Label("未検出", systemImage: "xmark.circle")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        } else {
                            ProgressView().scaleEffect(0.6)
                        }
                    }
                }
            }

            Section("CLI パス情報") {
                if let path = CLIResolver.resolve(backend) {
                    LabeledContent("検出パス", value: path)
                        .font(.subheadline)
                } else {
                    Text("\(backend.displayName) が見つかりません。\nインストール後、アプリを再起動してください。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text("検索順: \(backend.searchPaths.joined(separator: ", "))、PATH")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear { checkCLIs() }
    }

    private func checkCLIs() {
        for b in AIBackend.allCases {
            cliStatus[b] = CLIResolver.isAvailable(b)
        }
    }
}
