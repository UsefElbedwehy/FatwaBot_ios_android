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
    /// The current period's calendar bounds, for a "resets on" display — not
    /// the scoring window (which ends at "now", not the boundary). `nil` for
    /// `lifetime` (no reset) and for `seasonal`/`challenge` boards an admin
    /// hasn't dated yet.
    public let periodStartsAt: Date?
    public let periodEndsAt: Date?

    public init(
        key: String, name: String, scope: String, period: String,
        joined: Bool, myRank: Int?, entries: [LeaderboardEntry],
        periodStartsAt: Date? = nil, periodEndsAt: Date? = nil
    ) {
        self.key = key
        self.name = name
        self.scope = scope
        self.period = period
        self.joined = joined
        self.myRank = myRank
        self.entries = entries
        self.periodStartsAt = periodStartsAt
        self.periodEndsAt = periodEndsAt
    }

    enum CodingKeys: String, CodingKey {
        case key, name, scope, period, joined, entries
        case myRank = "my_rank"
        case periodStartsAt = "period_starts_at"
        case periodEndsAt = "period_ends_at"
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
    /// ISO 3166-1 alpha-2. Sent only for country-scope boards; the backend
    /// stores it only for those, and rejects the join without it.
    let country: String?
}

// `city` clearing (explicit null) is a PATCH-only edge case not exposed by the
// join/leave-driven UI in this pass — leaving a board already clears its city
// association (docs/features/leaderboard.md), so only additive updates are needed here.
struct UpdateMembershipRequest: Encodable {
    let publish_name: Bool?
    let city: String?
}
