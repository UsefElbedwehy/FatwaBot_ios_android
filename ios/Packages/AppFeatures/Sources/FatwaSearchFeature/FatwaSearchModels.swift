import SwiftUI

/// The three entry points (docs/features/ai-search-m5.0-spec.md §Modes),
/// matching the reference app exactly. Declaration order is display order —
/// the Home cards read fatwa · hadith · question in that order.
public enum FatwaSearchMode: String, Codable, Hashable, CaseIterable, Sendable {
    case fatwa, hadith, general

    /// Reuses the keys the Home intent cards already localize under — same
    /// wording everywhere the mode is named, no duplicate strings.
    public var titleKey: LocalizedStringKey {
        switch self {
        case .fatwa: return "home.card.fatwa"
        case .hadith: return "home.card.hadith"
        case .general: return "home.card.question"
        }
    }

    public var placeholderKey: LocalizedStringKey {
        switch self {
        case .fatwa: return "fatwa_search.placeholder.fatwa"
        case .hadith: return "fatwa_search.placeholder.hadith"
        case .general: return "fatwa_search.placeholder.general"
        }
    }

    public var hintKey: LocalizedStringKey {
        switch self {
        case .fatwa: return "fatwa_search.hint.fatwa"
        case .hadith: return "fatwa_search.hint.hadith"
        case .general: return "fatwa_search.hint.general"
        }
    }

    public var systemImage: String {
        switch self {
        case .fatwa: return "magnifyingglass"
        case .hadith: return "book.fill"
        case .general: return "questionmark.bubble.fill"
        }
    }
}

struct SearchRequestBody: Encodable, Sendable {
    let question: String
    let mode: String
}

/// One verified citation backing an answer — server-enforced substring match
/// against the source chunk (never a fabricated quote; see backend
/// citation_verify.ts).
public struct SearchCitation: Decodable, Equatable, Identifiable, Sendable {
    public let chunkId: String
    public let scholar: String
    public let sourceTitle: String
    public let pageNumber: Int?
    public let videoTimestamp: Int?
    public let quotedText: String

    public var id: String { chunkId }

    enum CodingKeys: String, CodingKey {
        case chunkId = "chunk_id"
        case scholar
        case sourceTitle = "source_title"
        case pageNumber = "page_number"
        case videoTimestamp = "video_timestamp"
        case quotedText = "quoted_text"
    }
}

public struct SearchResponse: Decodable, Equatable, Sendable {
    public let answer: String
    public let citations: [SearchCitation]
    public let refused: Bool
    public let mode: String
}
