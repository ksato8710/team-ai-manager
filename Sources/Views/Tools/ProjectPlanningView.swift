import SwiftUI
import UniformTypeIdentifiers

struct ProjectPlanningView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingAbout = false
    @State private var inputText = ""

    var body: some View {
        ProjectPlanningContent(
            service: appState.charterService,
            showingAbout: $showingAbout,
            inputText: $inputText
        )
        .sheet(isPresented: $showingAbout) {
            ProjectPlanningAboutSheet(isPresented: $showingAbout)
        }
    }
}

// Separate view that directly observes CharterAIService
struct ProjectPlanningContent: View {
    @ObservedObject var service: CharterAIService
    @Binding var showingAbout: Bool
    @Binding var inputText: String
    @StateObject private var speechRecognizer = SpeechRecognizer()

    var body: some View {
        HStack(spacing: 0) {
            // Left: Charter list + Chat
            VStack(spacing: 0) {
                if service.currentCharter != nil {
                    chatPanel
                } else {
                    charterListPanel
                }
            }
            .frame(minWidth: 400, idealWidth: 500, maxWidth: .infinity)

            Divider()

            // Right: Document panel
            if service.currentCharter != nil {
                documentPanel
            } else {
                emptyDocumentPanel
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .onAppear {
            service.loadCharters()
        }
    }

    // MARK: - Charter List

    private var charterListPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Text("プロジェクト憲章")
                    .font(.title2).fontWeight(.bold)

                Button { showingAbout = true } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("このツールについて")

                Spacer()

                Button {
                    promptNewCharterTitle()
                } label: {
                    Label("新規作成", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

            if service.charters.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("プロジェクト憲章がありません")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("「新規作成」からAIと対話しながら\nプロジェクト憲章を作成しましょう")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                Spacer()
            } else {
                List {
                    ForEach(service.charters) { charter in
                        charterRow(charter)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                service.loadCharter(id: charter.id!)
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    if let id = charter.id {
                                        service.deleteCharter(id: id)
                                    }
                                } label: {
                                    Label("削除", systemImage: "trash")
                                }
                            }
                    }
                    .onDelete { indexSet in
                        for idx in indexSet {
                            if let id = service.charters[idx].id {
                                service.deleteCharter(id: id)
                            }
                        }
                    }
                }
            }
        }
    }

    private func charterRow(_ charter: ProjectCharter) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(charter.title)
                    .font(.headline)
                Spacer()
                statusBadge(charter.status)
            }
            HStack {
                Text("\(charter.filledSectionCount)/\(charter.totalSectionCount) セクション")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let date = charter.updatedAt {
                    Text(date)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            ProgressView(value: Double(charter.filledSectionCount), total: Double(charter.totalSectionCount))
                .tint(progressColor(for: charter))
        }
        .padding(.vertical, 4)
    }

    private func statusBadge(_ status: CharterStatus) -> some View {
        Text(status.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(statusColor(status).opacity(0.15))
            .foregroundStyle(statusColor(status))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func statusColor(_ status: CharterStatus) -> Color {
        switch status {
        case .draft: return .orange
        case .inProgress: return .blue
        case .completed: return .green
        }
    }

    private func progressColor(for charter: ProjectCharter) -> Color {
        let ratio = Double(charter.filledSectionCount) / Double(charter.totalSectionCount)
        if ratio >= 0.8 { return .green }
        if ratio >= 0.4 { return .blue }
        return .orange
    }

    // MARK: - Chat Panel

    private var chatPanel: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        service.currentCharter = nil
                        service.messages = []
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("一覧")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                if let charter = service.currentCharter {
                    Text(charter.title)
                        .font(.headline)
                }

                Spacer()

                statusBadge(service.currentCharter?.status ?? .draft)

                Button {
                    if let id = service.currentCharter?.id {
                        let alert = NSAlert()
                        alert.messageText = "この憲章を削除しますか？"
                        alert.informativeText = "「\(service.currentCharter?.title ?? "")」を削除すると、会話履歴も含めて元に戻せません。"
                        alert.alertStyle = .warning
                        alert.addButton(withTitle: "削除")
                        alert.addButton(withTitle: "キャンセル")
                        if alert.runModal() == .alertFirstButtonReturn {
                            service.deleteCharter(id: id)
                        }
                    }
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .help("この憲章を削除")
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(service.messages) { msg in
                            messageBubble(msg)
                                .id(msg.id)
                        }
                        if service.isGenerating {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("考え中...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding()
                }
                .onChange(of: service.messages.count) { _, _ in
                    if let lastId = service.messages.last?.id {
                        withAnimation {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Input
            chatInput
        }
    }

    private func messageBubble(_ message: CharterMessage) -> some View {
        HStack(alignment: .top) {
            if message.isUser { Spacer(minLength: 60) }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                if let target = message.sectionTarget {
                    Label(target, systemImage: "tag")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
                Text(message.content)
                    .font(.body)
                    .textSelection(.enabled)
                    .padding(10)
                    .background(
                        message.isUser
                            ? Color.accentColor.opacity(0.15)
                            : Color(nsColor: .controlBackgroundColor)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            if message.isAssistant { Spacer(minLength: 60) }
        }
    }

    private var chatInput: some View {
        VStack(spacing: 4) {
            // Recording indicator
            if speechRecognizer.isRecording {
                HStack(spacing: 6) {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                    Text(speechRecognizer.transcript.isEmpty ? "聞いています..." : speechRecognizer.transcript)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.top, 4)
            }

            if let error = speechRecognizer.errorMessage {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 12)
            }

            HStack(alignment: .bottom, spacing: 8) {
                ZStack(alignment: .topLeading) {
                    // Placeholder
                    if inputText.isEmpty {
                        Text("メッセージを入力...")
                            .foregroundStyle(.tertiary)
                            .padding(.leading, 5)
                            .padding(.top, 8)
                    }
                    TextEditor(text: $inputText)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 36, maxHeight: 120)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .textBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )

                VStack(spacing: 6) {
                    // Mic button
                    Button {
                        if speechRecognizer.isRecording {
                            speechRecognizer.stopRecording()
                            let text = speechRecognizer.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !text.isEmpty {
                                if inputText.isEmpty {
                                    inputText = text
                                } else {
                                    inputText += " " + text
                                }
                            }
                        } else {
                            speechRecognizer.startRecording()
                        }
                    } label: {
                        Image(systemName: speechRecognizer.isRecording ? "mic.fill" : "mic")
                            .font(.title3)
                            .foregroundStyle(speechRecognizer.isRecording ? .red : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help(speechRecognizer.isRecording ? "音声入力を停止" : "音声入力を開始")

                    // Send button
                    Button {
                        sendMessage()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || service.isGenerating)
                }
            }
            .padding(12)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .onChange(of: speechRecognizer.transcript) { _, newValue in
            // Live preview: update input text while recording
            if speechRecognizer.isRecording && !newValue.isEmpty {
                inputText = newValue
            }
        }
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        service.sendMessage(text)
    }

    private func promptNewCharterTitle() {
        let alert = NSAlert()
        alert.messageText = "新規プロジェクト憲章"
        alert.informativeText = "プロジェクト名を入力してください"
        alert.addButton(withTitle: "作成")
        alert.addButton(withTitle: "キャンセル")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        textField.placeholderString = "プロジェクト名"
        alert.accessoryView = textField
        alert.window.initialFirstResponder = textField

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let title = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !title.isEmpty {
                service.createCharter(title: title)
            }
        }
    }

    // MARK: - Document Panel

    private var documentPanel: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("プロジェクト憲章")
                    .font(.headline)
                Spacer()
                if let charter = service.currentCharter {
                    Text("\(charter.filledSectionCount)/\(charter.totalSectionCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button("ドキュメント出力") {
                    let doc = service.compileDocument()
                    guard !doc.isEmpty else { return }

                    let panel = NSSavePanel()
                    panel.title = "プロジェクト憲章を保存"
                    panel.nameFieldStringValue = "\(service.currentCharter?.title ?? "プロジェクト憲章").md"
                    panel.allowedContentTypes = [.plainText]
                    panel.allowsOtherFileTypes = true

                    if panel.runModal() == .OK, let url = panel.url {
                        do {
                            try doc.write(to: url, atomically: true, encoding: .utf8)
                        } catch {
                            let alert = NSAlert()
                            alert.messageText = "保存に失敗しました"
                            alert.informativeText = error.localizedDescription
                            alert.alertStyle = .critical
                            alert.runModal()
                        }
                    }
                }
                .buttonStyle(.bordered)
                .disabled(service.currentCharter?.filledSectionCount == 0)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Sections
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(CharterSection.allCases) { section in
                        sectionRow(section)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
        .frame(minWidth: 380, idealWidth: 480)
    }

    private func sectionRow(_ section: CharterSection) -> some View {
        let content = service.currentCharter?.content(for: section)
        let hasContent = content != nil && !content!.isEmpty

        return Button {
            service.focusSection(section)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                // Left accent bar
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(hasContent ? Color.green : Color.gray.opacity(0.2))
                    .frame(width: 3)

                Image(systemName: section.icon)
                    .font(.system(size: 14))
                    .frame(width: 22)
                    .foregroundStyle(hasContent ? .green : .secondary)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(section.displayName)
                            .font(.headline)
                        Spacer()
                        Image(systemName: hasContent ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(hasContent ? Color.green : Color.gray.opacity(0.3))
                            .font(.subheadline)
                    }

                    if let content, !content.isEmpty {
                        Text(content)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineSpacing(6)
                            .lineLimit(3)
                    } else {
                        Text("未入力 — クリックして入力")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private var emptyDocumentPanel: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.clipboard")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("プロジェクト憲章を選択または\n新規作成してください")
                .font(.headline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

}

// MARK: - About Sheet

struct ProjectPlanningAboutSheet: View {
    @Binding var isPresented: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "list.clipboard")
                            .font(.system(size: 36))
                            .foregroundStyle(Color.accentColor)
                        Text("Project Planning Tool")
                            .font(.title2).fontWeight(.bold)
                        Text("AIファシリテーターによるプロジェクト憲章作成")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                Divider()

                section(icon: "lightbulb", title: "コンセプト", content: """
                「ふわっとしたゴール・制約」→ AIとの対話的壁打ち → 「構造化されたプロジェクト憲章」

                プロジェクト計画の初期段階では、ゴールやスコープが曖昧なことがほとんどです。\
                このツールは、AIファシリテーターが段階的に質問をリードすることで、\
                属人的な計画策定プロセスを仕組み化します。
                """)

                section(icon: "rectangle.split.2x1", title: "なぜ Side-by-Side UI か", content: """
                左パネル（チャット）: ユーザーは自然言語でふわっと話すだけでOK。AIが内容を咀嚼・構造化します。

                右パネル（ドキュメント）: 13セクションの充足状況がリアルタイムで可視化。\
                セクションをクリックすれば、そこにフォーカスした対話に切り替わります。
                """)

                section(icon: "arrow.right.arrow.left", title: "なぜ4フェーズ構成か", content: """
                最初から全項目を聞くのではなく、ユーザーの思考の流れに沿って段階的に情報を引き出します。
                """)

                phase(number: 1, name: "INTAKE", desc: "大枠ヒアリング（何を・誰に・なぜ・いつまでに）", turns: "1-5ターン")
                phase(number: 2, name: "DRAFT REVIEW", desc: "初回ドラフト確認、大枠のズレ修正", turns: "1-3ターン")
                phase(number: 3, name: "SECTION REFINEMENT", desc: "空欄・弱いセクションを個別に深掘り", turns: "3-10ターン")
                phase(number: 4, name: "FINALIZATION", desc: "完全性チェック、セクション間の整合性確認", turns: "1-2ターン")

                section(icon: "doc.text", title: "なぜ13セクションか", content: """
                プロジェクト憲章のベストプラクティスに基づく標準項目に加え、デザイン組織特有の項目を追加:

                - ターゲットユーザー — デザインは誰のためかが最重要
                - 成功指標（KPI） — 「良いデザイン」を定量化する基準
                - デリバラブル — 成果物の形式・粒度を事前に合意
                - デザイン方針 — ブランドガイドライン、アクセシビリティ要件
                - 承認プロセス — 意思決定者とレビュータイミングの明確化
                """)

                section(icon: "cylinder.split.1x2", title: "Team AI Manager ならではの強み", content: """
                既存のデータベースを活用してAIの提案品質を高める設計:

                - メンバー × スキル → 体制セクションで最適アサイン提案
                - メンバー × 稼働率 → 空きリソースの代替候補提示
                - 過去プロジェクト → 類似案件のスケジュール・体制を参考値に
                - クライアント情報 → 過去の取引実績・関係ステータスを参照
                - ナレッジベース → デザイン原則・ガイドラインの引用
                """)

                section(icon: "arrow.triangle.branch", title: "カスケード更新", content: """
                セクション間には依存関係があります。例えば「スコープ」を変更すると、\
                デリバラブル・スケジュール・リスク・体制にも影響が波及します。
                """)

                section(icon: "gearshape.2", title: "技術的な設計判断", content: """
                ローカルの Claude Code CLI（サブスクリプション認証）を使い、\
                ユーザーの入力を理解してプロジェクト憲章の各セクションを自動的に更新します。

                1. claude -p でローカルCLIを呼び出し、サブスクリプション認証で動作
                2. システムプロンプトに現在の憲章全体 + 会話履歴を含め、文脈を維持
                3. セクション更新マーカーにより、AIの応答から自動的にドキュメントを更新
                4. APIキー不要 — Claude Code のサブスクリプションをそのまま利用
                """)

                HStack {
                    Spacer()
                    Button("閉じる") { isPresented = false }
                        .keyboardShortcut(.cancelAction)
                    Spacer()
                }
            }
            .padding(32)
        }
        .frame(width: 600, height: 700)
    }

    private func section(icon: String, title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.headline)
            Text(content)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func phase(number: Int, name: String, desc: String, turns: String) -> some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.accentColor))

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(turns)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.leading, 24)
    }
}
