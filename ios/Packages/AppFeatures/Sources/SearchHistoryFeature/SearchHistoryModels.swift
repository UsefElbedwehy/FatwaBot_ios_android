import Foundation

public struct SearchHistoryEntry: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let source: String
    public let queryText: String
    public let locale: String
    public let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, source, locale
        case queryText = "query_text"
        case createdAt = "created_at"
    }
}

struct ListSearchHistoryResponse: Decodable {
    let entries: [SearchHistoryEntry]
}

struct RecordSearchRequest: Encodable {
    let source: String
    let query_text: String
    let locale: String
}
