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
        .frame(width: 500, height: 300)
    }
}

struct GeneralSettingsView: View {
    @AppStorage("databasePath") private var databasePath = ""

    var body: some View {
        Form {
            Text("Database is stored in Application Support/TeamAIManager/")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct AISettingsView: View {
    @AppStorage("claudeApiKey") private var claudeApiKey = ""

    var body: some View {
        Form {
            SecureField("Claude API Key", text: $claudeApiKey)
            Text("Used for AI-powered scanning, analysis, and recommendations.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .padding()
    }
}
