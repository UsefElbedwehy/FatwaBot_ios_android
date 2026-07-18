import Foundation

public struct LeaderboardEntry: Decodable, Equatable, Sendable {
    public let rank: Int
    public let score: Double
    public let displayName: String

    enum CodingKeys: String, CodingKey {
        case rank, score
        case displayName = "display_name"
    }
}

public struct LeaderboardBoard: Decodable, Equatable, Identifiable, Sendable {
    public var id: String { key }
    public let key: String
    public let name: String
    public let scope: String
    public let period: String
    public let joined: Bool
    public let myRank: Int?
    public let entries: [LeaderboardEntry]

    enum CodingKeys: String, CodingKey {
        case key, name, scope, period, joined, entries
        case myRank = "my_rank"
    }
}

public struct LeaderboardMembership: Codable, Equatable, Sendable {
    public let handle: String
    public let publishName: Bool
    public let city: String?

    enum CodingKeys: String, CodingKey {
        case handle
        case publishName = "publish_name"
        case city
    }
}

struct ListBoardsResponse: Decodable {
    let boards: [LeaderboardBoard]
}

struct JoinLeaderboardRequest: Encodable {
    let publish_name: Bool
    let city: String?
}

// `city` clearing (explicit null) is a PATCH-only edge case not exposed by the
// join/leave-driven UI in this pass — leaving a board already clears its city
// association (docs/features/leaderboard.md), so only additive updates are needed here.
struct UpdateMembershipRequest: Encodable {
    let publish_name: Bool?
    let city: String?
}
