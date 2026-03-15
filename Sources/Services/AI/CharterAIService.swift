import Foundation
import GRDB

@MainActor
final class CharterAIService: ObservableObject {
    @Published var currentCharter: ProjectCharter?
    @Published var messages: [CharterMessage] = []
    @Published var charters: [ProjectCharter] = []
    @Published var isGenerating = false
    @Published var errorMessage: String?

    private let database: DatabaseManager

    init(database: DatabaseManager) {
        self.database = database
    }

    // MARK: - Charter CRUD

    func loadCharters() {
        do {
            charters = try database.read { db in
                try ProjectCharter
                    .order(ProjectCharter.Columns.updatedAt.desc)
                    .fetchAll(db)
            }
        } catch {
            print("Load charters error: \(error)")
        }
    }

    func createCharter(title: String) {
        do {
            var charter = ProjectCharter(title: title, status: .draft)
            try database.write { db in
                try charter.insert(db)
            }
            currentCharter = charter
            messages = []
            loadCharters()

            // Send initial AI greeting
            let greeting = buildInitialGreeting(title: title)
            appendAssistantMessage(greeting)
        } catch {
            print("Create charter error: \(error)")
        }
    }

    func loadCharter(id: Int64) {
        do {
            currentCharter = try database.read { db in
                try ProjectCharter.fetchOne(db, id: id)
            }
            guard let charter = currentCharter else { return }
            messages = try database.read { db in
                try CharterMessage
                    .filter(CharterMessage.Columns.charterId == charter.id!)
                    .order(CharterMessage.Columns.createdAt.asc)
                    .fetchAll(db)
            }
        } catch {
            print("Load charter error: \(error)")
        }
    }

    func deleteCharter(id: Int64) {
        do {
            _ = try database.write { db in
                try ProjectCharter.deleteOne(db, id: id)
            }
            if currentCharter?.id == id {
                currentCharter = nil
                messages = []
            }
            loadCharters()
        } catch {
            print("Delete charter error: \(error)")
        }
    }

    // MARK: - Conversation

    func sendMessage(_ text: String, sectionTarget: CharterSection? = nil) {
        guard let charterId = currentCharter?.id else { return }

        // Persist user message
        var userMsg = CharterMessage(
            charterId: charterId, role: "user", content: text,
            sectionTarget: sectionTarget?.rawValue
        )
        do {
            try database.write { db in
                try userMsg.insert(db)
            }
            messages.append(userMsg)
        } catch {
            print("Save user message error: \(error)")
            return
        }

        // Call AI CLI
        isGenerating = true
        errorMessage = nil

        Task.detached { [weak self] in
            do {
                let response = try await self?.callAICLI(sectionTarget: sectionTarget)
                await MainActor.run {
                    guard let self, let response else { return }
                    self.appendAssistantMessage(response.message, sectionTarget: response.sectionTarget)
                    if !response.sectionUpdates.isEmpty {
                        self.updateCharterSections(response.sectionUpdates)
                    }
                    self.isGenerating = false
                }
            } catch {
                await MainActor.run {
                    guard let self else { return }
                    let errorText = "エラーが発生しました: \(error.localizedDescription)"
                    self.errorMessage = errorText
                    self.appendAssistantMessage(errorText)
                    self.isGenerating = false
                }
            }
        }
    }

    func focusSection(_ section: CharterSection) {
        guard currentCharter != nil else { return }
        let currentContent = currentCharter?.content(for: section)

        let prompt: String
        if let content = currentContent, !content.isEmpty {
            prompt = "「\(section.displayName)」セクションの現在の内容を確認しましょう。改善したい点や追加情報はありますか？\n\n現在の内容:\n\(content)"
        } else {
            prompt = sectionPrompt(for: section)
        }
        appendAssistantMessage(prompt, sectionTarget: section)
    }

    // MARK: - Document Compilation

    func compileDocument() -> String {
        guard let charter = currentCharter else { return "" }
        var doc = "# \(charter.title)\n\n"

        for section in CharterSection.allCases {
            if let content = charter.content(for: section), !content.isEmpty {
                doc += "## \(section.displayName)\n\n\(content)\n\n"
            }
        }

        do {
            try database.write { db in
                try db.execute(
                    sql: "UPDATE project_charters SET full_document = ?, updated_at = datetime('now') WHERE id = ?",
                    arguments: [doc, charter.id]
                )
            }
            currentCharter?.fullDocument = doc
        } catch {
            print("Compile document error: \(error)")
        }

        return doc
    }

    // MARK: - AI CLI Call

    private struct AIResponse {
        let message: String
        let sectionTarget: CharterSection?
        let sectionUpdates: [CharterSection: String]
    }

    private func callAICLI(sectionTarget: CharterSection?) async throws -> AIResponse {
        let systemPrompt = await MainActor.run { buildSystemPrompt(sectionTarget: sectionTarget) }
        let conversationMessages = await MainActor.run { messages }

        // Build the full prompt: system context + conversation history
        var fullPrompt = systemPrompt + "\n\n---\n\n以下がこれまでの会話履歴です:\n\n"
        for msg in conversationMessages {
            let role = msg.isUser ? "ユーザー" : "アシスタント"
            fullPrompt += "【\(role)】\n\(msg.content)\n\n"
        }
        fullPrompt += "上記の会話の最後のユーザーメッセージに対して回答してください。"

        // Resolve CLI path for selected backend
        let backend = AIBackend.current
        guard let cliPath = CLIResolver.resolve(backend) else {
            throw CharterAIError.cliNotFound(backend: backend)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: cliPath)

        switch backend {
        case .claude:
            process.arguments = ["-p", fullPrompt, "--output-format", "json"]
        case .codex:
            process.arguments = ["-p", fullPrompt, "--output-format", "json"]
        }

        var env = ProcessInfo.processInfo.environment
        // For Claude: remove API key to use subscription auth
        if backend == .claude {
            env.removeValue(forKey: "ANTHROPIC_API_KEY")
        }
        process.environment = env

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
        let outputString = String(data: outputData, encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            let errData = stderr.fileHandleForReading.readDataToEndOfFile()
            let errString = String(data: errData, encoding: .utf8) ?? "Unknown error"
            throw CharterAIError.cliError(message: errString.isEmpty ? outputString : errString)
        }

        // Parse response (both CLIs support JSON output)
        let responseText = Self.parseJSONResponse(outputData) ?? outputString.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !responseText.isEmpty else {
            throw CharterAIError.emptyResponse
        }

        let sectionUpdates = parseSectionUpdates(from: responseText)

        return AIResponse(
            message: responseText,
            sectionTarget: sectionTarget ?? sectionUpdates.keys.first,
            sectionUpdates: sectionUpdates
        )
    }

    /// Parse JSON response from CLI (shared format for Claude / Codex)
    private static func parseJSONResponse(_ data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        // Claude format
        if let result = json["result"] as? String {
            if let isError = json["is_error"] as? Bool, isError {
                return nil
            }
            if let cost = json["total_cost_usd"] as? Double {
                print("[AI] Response received. Cost: $\(String(format: "%.4f", cost))")
            }
            if let duration = json["duration_api_ms"] as? Int {
                print("[AI] API duration: \(duration)ms")
            }
            return result
        }

        // Codex format
        if let choices = json["choices"] as? [[String: Any]],
           let first = choices.first,
           let message = first["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content
        }

        // Generic: try "output" or "text" keys
        if let output = json["output"] as? String { return output }
        if let text = json["text"] as? String { return text }

        return nil
    }

    private func buildSystemPrompt(sectionTarget: CharterSection?) -> String {
        guard let charter = currentCharter else { return "" }

        var prompt = """
        あなたはデザイン組織のプロジェクト計画AIファシリテーターです。
        ユーザーとの対話を通じて、プロジェクト憲章（Project Charter）を段階的に作成していきます。

        ## プロジェクト情報
        - タイトル: \(charter.title)
        - ステータス: \(charter.status.displayName)

        ## 現在のプロジェクト憲章の内容
        """

        for section in CharterSection.allCases {
            let content = charter.content(for: section)
            let status = (content != nil && !content!.isEmpty) ? content! : "（未入力）"
            prompt += "\n### \(section.displayName)\n\(status)\n"
        }

        prompt += """

        ## あなたの役割
        1. ユーザーの曖昧な入力から、プロジェクト憲章の各セクションに適切な内容を抽出・構造化する
        2. 段階的に質問をリードし、全13セクションを埋めていく
        3. セクション間の整合性を確認し、矛盾があれば指摘する
        4. デザイン組織特有の観点（ターゲットユーザー、デザイン方針、成果物の形式等）を重視する

        ## 応答ルール
        - 日本語で回答する
        - 簡潔かつ実用的に
        - ユーザーの発言を受け止めてから質問する（いきなり質問を列挙しない）
        - 一度に聞く質問は2-3個まで
        """

        if let target = sectionTarget {
            prompt += "\n\n## 現在のフォーカス\n「\(target.displayName)」セクションに集中して対話してください。"
        }

        prompt += """

        ## セクション更新指示
        ユーザーの回答からプロジェクト憲章のセクションを更新すべき場合、回答の最後に以下の形式で更新内容を記述してください。
        この部分はシステムが自動的にパースし、右パネルのドキュメントに反映します。

        ---SECTION_UPDATES---
        [セクション名]: 更新内容
        ---END_UPDATES---

        使用可能なセクション名: summary, background, objectives, scope, targetUsers, successCriteria, constraints, deliverables, team, schedule, risks, designPrinciples, approvalProcess

        複数行の更新内容は1行にまとめてください。更新が不要な場合はSECTION_UPDATESブロックを省略してください。
        """

        return prompt
    }

    private func parseSectionUpdates(from text: String) -> [CharterSection: String] {
        var updates: [CharterSection: String] = [:]

        guard let startRange = text.range(of: "---SECTION_UPDATES---"),
              let endRange = text.range(of: "---END_UPDATES---") else {
            return updates
        }

        let updatesText = String(text[startRange.upperBound..<endRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        for line in updatesText.components(separatedBy: "\n") {
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let sectionKey = parts[0].trimmingCharacters(in: .whitespaces)
            let content = parts[1].trimmingCharacters(in: .whitespaces)

            if let section = CharterSection.allCases.first(where: { $0.rawValue == sectionKey }) {
                updates[section] = content
            }
        }

        return updates
    }

    // MARK: - Private Helpers

    private func appendAssistantMessage(_ content: String, sectionTarget: CharterSection? = nil) {
        guard let charterId = currentCharter?.id else { return }

        // Strip section update markers from displayed message
        var displayContent = content
        if let startRange = content.range(of: "---SECTION_UPDATES---") {
            displayContent = String(content[..<startRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var msg = CharterMessage(
            charterId: charterId, role: "assistant", content: displayContent,
            sectionTarget: sectionTarget?.rawValue
        )
        do {
            try database.write { db in
                try msg.insert(db)
            }
            messages.append(msg)
        } catch {
            print("Save assistant message error: \(error)")
        }
    }

    private func updateCharterSections(_ updates: [CharterSection: String]) {
        guard var charter = currentCharter else { return }
        for (section, content) in updates {
            charter.setContent(content, for: section)
        }
        charter.status = .inProgress
        do {
            try database.write { db in
                try charter.update(db)
            }
            currentCharter = charter
            loadCharters()
        } catch {
            print("Update charter sections error: \(error)")
        }
    }

    private func sectionPrompt(for section: CharterSection) -> String {
        switch section {
        case .summary:
            return "このプロジェクトを2-3文で説明してください。エレベーターピッチのように、「何を」「誰のために」「なぜ」が分かるように。"
        case .background:
            return "このプロジェクトが生まれた背景を教えてください。どんな課題があり、なぜ今このプロジェクトが必要なのか。"
        case .objectives:
            return "このプロジェクトで達成したいゴールを教えてください。できればSMART（具体的・測定可能・達成可能・関連性・期限）な目標が理想です。"
        case .scope:
            return "このプロジェクトの範囲を教えてください。「やること」と「やらないこと」の境界線はどこですか？"
        case .targetUsers:
            return "誰のためのプロジェクトですか？ターゲットユーザーのセグメント、特徴、主なニーズを教えてください。"
        case .successCriteria:
            return "何をもって「成功」としますか？定量的な指標（KPI）と定性的な判断基準を教えてください。"
        case .constraints:
            return "技術的制約、予算、期限、既存システムとの依存関係、法規制など、考慮すべき制約条件を教えてください。"
        case .deliverables:
            return "最終的な成果物は何ですか？（例: UIデザイン、プロトタイプ、デザインシステム、リサーチレポート等）形式と粒度も含めて。"
        case .team:
            return "どのような体制で進めますか？必要なロール、人数、スキルレベルの要件を教えてください。"
        case .schedule:
            return "プロジェクトのタイムラインを教えてください。フェーズ分け、主要マイルストーン、最終期限など。"
        case .risks:
            return "想定されるリスクや懸念事項はありますか？技術的リスク、スケジュールリスク、ステークホルダーリスクなど。"
        case .designPrinciples:
            return "このプロジェクトで大切にしたいデザイン方針や原則はありますか？参照すべきブランドガイドライン、アクセシビリティ要件なども。"
        case .approvalProcess:
            return "レビュー・承認のプロセスはどうしますか？意思決定者は誰で、どのタイミングで承認を得ますか？"
        }
    }

    private func buildInitialGreeting(title: String) -> String {
        """
        「\(title)」のプロジェクト憲章を一緒に作成しましょう。

        まず、このプロジェクトについて教えてください。ふわっとした段階で構いません：
        - **どんなプロジェクト** ですか？
        - **きっかけ** は何ですか？（クライアントからの相談、社内の課題など）
        - **大まかな期待値** はありますか？

        自由にお話しください。こちらで内容を整理し、右側のプロジェクト憲章に反映していきます。
        """
    }
}

// MARK: - Error Types

enum CharterAIError: LocalizedError {
    case cliNotFound(backend: AIBackend)
    case cliError(message: String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .cliNotFound(let backend):
            return "\(backend.displayName) CLI が見つかりません。インストールされているか確認してください。"
        case .cliError(let message):
            return "AI CLI エラー: \(message)"
        case .emptyResponse:
            return "AI からの応答が空でした。"
        }
    }
}
