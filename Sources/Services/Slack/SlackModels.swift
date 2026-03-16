import Foundation

// MARK: - Slack API Response Types

struct SlackMessage: Codable {
    let user: String?
    let text: String
    let ts: String
    let threadTs: String?
    let replyCount: Int?

    enum CodingKeys: String, CodingKey {
        case user, text, ts
        case threadTs = "thread_ts"
        case replyCount = "reply_count"
    }

    var date: Date? {
        guard let interval = Double(ts) else { return nil }
        return Date(timeIntervalSince1970: interval)
    }
}

struct SlackChannelInfo: Codable, Identifiable {
    let id: String
    let name: String
    let topic: SlackTopic?
    let purpose: SlackTopic?
    let numMembers: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, topic, purpose
        case numMembers = "num_members"
    }
}

struct SlackTopic: Codable {
    let value: String
}

struct SlackAuthInfo: Codable {
    let ok: Bool
    let team: String?
    let user: String?
    let teamId: String?

    enum CodingKeys: String, CodingKey {
        case ok, team, user
        case teamId = "team_id"
    }
}

// MARK: - API Response Wrappers

struct SlackHistoryResponse: Codable {
    let ok: Bool
    let messages: [SlackMessage]?
    let hasMore: Bool?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case ok, messages
        case hasMore = "has_more"
        case error
    }
}

struct SlackChannelResponse: Codable {
    let ok: Bool
    let channel: SlackChannelInfo?
    let error: String?
}

struct SlackChannelListResponse: Codable {
    let ok: Bool
    let channels: [SlackChannelInfo]?
    let error: String?
}

// MARK: - Analysis Result

struct SlackAnalysisResult {
    let summary: String
    let statusUpdate: String?
    let keyTopics: [String]
    let actionItems: [String]
    let risks: [String]
}
