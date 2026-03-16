import Foundation

/// Slack Web API client using URLSession
final class SlackAPIClient: Sendable {
    private let botToken: String
    private static let baseURL = "https://slack.com/api"

    init(botToken: String) {
        self.botToken = botToken
    }

    /// Convenience: create from database config
    static func fromConfig(database: DatabaseManager) throws -> SlackAPIClient? {
        let config = try database.read { db in
            try SlackConfig.current(db: db)
        }
        guard let config else { return nil }
        return SlackAPIClient(botToken: config.botToken)
    }

    // MARK: - Auth

    func testAuth() async throws -> SlackAuthInfo {
        let data = try await request("auth.test")
        return try JSONDecoder().decode(SlackAuthInfo.self, from: data)
    }

    // MARK: - Channels

    func channelInfo(channelId: String) async throws -> SlackChannelInfo {
        let data = try await request("conversations.info", params: ["channel": channelId])
        let response = try JSONDecoder().decode(SlackChannelResponse.self, from: data)
        guard response.ok, let channel = response.channel else {
            throw SlackAPIError.apiError(response.error ?? "Unknown error")
        }
        return channel
    }

    func listChannels(limit: Int = 200) async throws -> [SlackChannelInfo] {
        let data = try await request("conversations.list", params: [
            "limit": "\(limit)",
            "types": "public_channel,private_channel",
            "exclude_archived": "true"
        ])
        let response = try JSONDecoder().decode(SlackChannelListResponse.self, from: data)
        guard response.ok else {
            throw SlackAPIError.apiError(response.error ?? "Unknown error")
        }
        return response.channels ?? []
    }

    // MARK: - Messages

    func fetchHistory(channelId: String, since: Date? = nil, limit: Int = 100) async throws -> [SlackMessage] {
        var params = ["channel": channelId, "limit": "\(limit)"]
        if let since {
            params["oldest"] = "\(since.timeIntervalSince1970)"
        }
        let data = try await request("conversations.history", params: params)
        let response = try JSONDecoder().decode(SlackHistoryResponse.self, from: data)
        guard response.ok else {
            throw SlackAPIError.apiError(response.error ?? "Unknown error")
        }
        return response.messages ?? []
    }

    // MARK: - Internal

    private func request(_ method: String, params: [String: String] = [:]) async throws -> Data {
        var components = URLComponents(string: "\(Self.baseURL)/\(method)")!
        if !params.isEmpty {
            components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        var urlRequest = URLRequest(url: components.url!)
        urlRequest.setValue("Bearer \(botToken)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SlackAPIError.networkError("Invalid response")
        }

        if httpResponse.statusCode == 429 {
            // Rate limited - wait and retry once
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                .flatMap(Double.init) ?? 2.0
            try await Task.sleep(nanoseconds: UInt64(retryAfter * 1_000_000_000))
            return try await request(method, params: params)
        }

        guard httpResponse.statusCode == 200 else {
            throw SlackAPIError.httpError(httpResponse.statusCode)
        }

        return data
    }
}

// MARK: - Errors

enum SlackAPIError: LocalizedError {
    case apiError(String)
    case httpError(Int)
    case networkError(String)
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .apiError(let msg): return "Slack API: \(msg)"
        case .httpError(let code): return "HTTP \(code)"
        case .networkError(let msg): return "Network: \(msg)"
        case .notConfigured: return "Slack が設定されていません。Settings > Slack で Bot Token を設定してください。"
        }
    }
}
