import Foundation
import GRDB

/// AI agent that analyzes Slack messages to extract project-relevant information
@MainActor
final class SlackAIAgent: ObservableObject {
    @Published var isProcessing = false
    @Published var errorMessage: String?

    private let database: DatabaseManager

    init(database: DatabaseManager) {
        self.database = database
    }

    /// Fetch and analyze messages for a project's Slack channel
    func syncProject(_ project: Project) async throws -> SlackAnalysisResult {
        guard let channelId = project.slackChannelId, !channelId.isEmpty else {
            throw SlackAPIError.apiError("Slack チャネルIDが設定されていません")
        }

        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }

        let client = try getSlackClient()
        let messages = try await client.fetchHistory(channelId: channelId, limit: 50)

        guard !messages.isEmpty else {
            return SlackAnalysisResult(
                summary: "メッセージが見つかりませんでした。",
                statusUpdate: nil, keyTopics: [], actionItems: [], risks: []
            )
        }

        let prompt = buildProjectPrompt(project: project, messages: messages)
        let responseText = try await callAICLI(prompt: prompt)
        return parseResult(responseText)
    }

    /// Fetch and analyze messages for a client's Slack channel
    func syncClient(_ client: Client) async throws -> SlackAnalysisResult {
        guard let channelId = client.slackChannelId, !channelId.isEmpty else {
            throw SlackAPIError.apiError("Slack チャネルIDが設定されていません")
        }

        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }

        let slackClient = try getSlackClient()
        let messages = try await slackClient.fetchHistory(channelId: channelId, limit: 50)

        guard !messages.isEmpty else {
            return SlackAnalysisResult(
                summary: "メッセージが見つかりませんでした。",
                statusUpdate: nil, keyTopics: [], actionItems: [], risks: []
            )
        }

        let prompt = buildClientPrompt(client: client, messages: messages)
        let responseText = try await callAICLI(prompt: prompt)
        return parseResult(responseText)
    }

    // MARK: - Private

    private func getSlackClient() throws -> SlackAPIClient {
        guard let client = try SlackAPIClient.fromConfig(database: database) else {
            throw SlackAPIError.notConfigured
        }
        return client
    }

    private func buildProjectPrompt(project: Project, messages: [SlackMessage]) -> String {
        let messagesText = messages.reversed().map { msg in
            let user = msg.user ?? "unknown"
            return "[\(user)] \(msg.text)"
        }.joined(separator: "\n")

        return """
        あなたはプロジェクト管理のAIアシスタントです。
        以下のSlackチャネルのメッセージを分析し、プロジェクトの状況を要約してください。

        ## プロジェクト情報
        - 名前: \(project.name)
        - ステータス: \(project.status.displayName)
        - フェーズ: \(project.phase?.displayName ?? "未設定")
        - サービスタイプ: \(project.serviceType.displayName)

        ## Slackメッセージ（最新\(messages.count)件）
        \(messagesText)

        ## 出力形式
        以下の形式で回答してください:

        ---SUMMARY---
        （プロジェクトの現在の状況を2-3文で要約）
        ---STATUS_UPDATE---
        （ステータス変更の提案がある場合のみ。例: active, on_hold など。なければ空）
        ---KEY_TOPICS---
        （主要な議論トピック、カンマ区切り）
        ---ACTION_ITEMS---
        （アクションアイテム、改行区切り）
        ---RISKS---
        （リスクや懸念事項、改行区切り）
        ---END---
        """
    }

    private func buildClientPrompt(client: Client, messages: [SlackMessage]) -> String {
        let messagesText = messages.reversed().map { msg in
            let user = msg.user ?? "unknown"
            return "[\(user)] \(msg.text)"
        }.joined(separator: "\n")

        return """
        あなたはクライアント関係管理のAIアシスタントです。
        以下のSlackチャネルのメッセージを分析し、クライアントとの関係状況を要約してください。

        ## クライアント情報
        - 名前: \(client.name)
        - 業界: \(client.industry.displayName)
        - 関係ステータス: \(client.relationshipStatus.displayName)

        ## Slackメッセージ（最新\(messages.count)件）
        \(messagesText)

        ## 出力形式
        以下の形式で回答してください:

        ---SUMMARY---
        （クライアントとの現在の関係状況を2-3文で要約）
        ---STATUS_UPDATE---
        （関係ステータス変更の提案がある場合のみ。なければ空）
        ---KEY_TOPICS---
        （主要な議論トピック、カンマ区切り）
        ---ACTION_ITEMS---
        （アクションアイテム、改行区切り）
        ---RISKS---
        （リスクや懸念事項、改行区切り）
        ---END---
        """
    }

    private func callAICLI(prompt: String) async throws -> String {
        let backend = AIBackend.current
        guard let cliPath = CLIResolver.resolve(backend) else {
            throw CharterAIError.cliNotFound(backend: backend)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: cliPath)

        process.arguments = ["-p", prompt, "--output-format", "json"]

        var env = ProcessInfo.processInfo.environment
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

        // Parse JSON output
        if let json = try? JSONSerialization.jsonObject(with: outputData) as? [String: Any],
           let result = json["result"] as? String {
            return result
        }
        return outputString.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseResult(_ text: String) -> SlackAnalysisResult {
        func extract(tag: String) -> String {
            guard let start = text.range(of: "---\(tag)---"),
                  let end = text.range(of: "---", range: start.upperBound..<text.endIndex) else {
                return ""
            }
            return String(text[start.upperBound..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let summary = extract(tag: "SUMMARY")
        let statusUpdate = {
            let s = extract(tag: "STATUS_UPDATE")
            return s.isEmpty ? nil : s
        }()
        let keyTopics = extract(tag: "KEY_TOPICS")
            .split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let actionItems = extract(tag: "ACTION_ITEMS")
            .split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let risks = extract(tag: "RISKS")
            .split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        return SlackAnalysisResult(
            summary: summary.isEmpty ? "分析結果を取得できませんでした。" : summary,
            statusUpdate: statusUpdate,
            keyTopics: keyTopics,
            actionItems: actionItems,
            risks: risks
        )
    }
}
