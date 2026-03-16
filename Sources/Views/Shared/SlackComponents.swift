import SwiftUI

// MARK: - Slack Section (reused in Project and Client detail views)

struct SlackSectionView: View {
    let channelId: String?
    let isSyncing: Bool
    let result: SlackAnalysisResult?
    let onEdit: () -> Void
    let onSync: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Slack", systemImage: "message")
                    .font(.headline)
                Spacer()

                if let channelId, !channelId.isEmpty {
                    Button(action: onSync) {
                        if isSyncing {
                            ProgressView().scaleEffect(0.6)
                        } else {
                            Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(isSyncing)
                }

                Button(action: onEdit) {
                    Label("設定", systemImage: "pencil")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if let channelId, !channelId.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "number")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(channelId)
                        .font(.caption)
                        .fontDesign(.monospaced)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Slack チャネルが未設定です")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            // Analysis results
            if let result {
                VStack(alignment: .leading, spacing: 8) {
                    Text(result.summary)
                        .font(.subheadline)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    if !result.keyTopics.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("トピック")
                                .font(.caption)
                                .fontWeight(.medium)
                            FlowTagsView(tags: result.keyTopics, color: .blue)
                        }
                    }

                    if !result.actionItems.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("アクションアイテム")
                                .font(.caption)
                                .fontWeight(.medium)
                            ForEach(result.actionItems, id: \.self) { item in
                                Label(item, systemImage: "checklist")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if !result.risks.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("リスク・懸念")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.orange)
                            ForEach(result.risks, id: \.self) { risk in
                                Label(risk, systemImage: "exclamationmark.triangle")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Flow Tags

struct FlowTagsView: View {
    let tags: [String]
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(color.opacity(0.1))
                    .foregroundStyle(color)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
    }
}

// MARK: - Slack Channel Edit Sheet

struct SlackChannelEditSheet: View {
    @Binding var channelId: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("Slack チャネル設定")
                .font(.title3)
                .fontWeight(.bold)

            Form {
                TextField("チャネルID (例: C0123456789)", text: $channelId)
                    .font(.body.monospaced())

                Text("Slack アプリでチャネル名を右クリック → 「リンクをコピー」でチャネルIDを取得できます。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .formStyle(.grouped)

            HStack {
                Button("キャンセル") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("保存") {
                    onSave(channelId.trimmingCharacters(in: .whitespacesAndNewlines))
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal)
        }
        .padding()
        .frame(width: 420, height: 250)
    }
}
