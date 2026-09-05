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

/// The ruling behind the coloured status dot. The API emits the five-fold fiqh
/// scale so nothing is lost server-side; folding it to the client's four
/// colours is a presentation decision made in `RulingDot`.
///
/// `none` is not "unknown" — it means the question has no ruling to give (a
/// hadith's grading, a du'a's wording) and no dot is drawn. Anything
/// unrecognised decodes to `none` too, so a ruling added server-side can never
/// break an older build.
public enum Ruling: String, Decodable, Equatable, Sendable {
    case wajib, mustahabb, halal, mubah, makruh, haram, none

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Ruling(rawValue: raw) ?? .none
    }
}

/// One scholar's position, rendered as its own card. Citations are not nested
/// here — the API keeps them one flat list so verification can check them
/// exhaustively, and each names its scholar, so the UI groups by that.
public struct ScholarAnswer: Decodable, Equatable, Identifiable, Sendable {
    public let scholar: String
    public let answer: String
    public let evidence: String?

    public var id: String { scholar + answer.prefix(24) }
}

/// Hadith mode's takhrij fields, laid out as separate rows.
public struct HadithVerdict: Decodable, Equatable, Sendable {
    public let text: String
    public let grade: String
    public let source: String?
    public let scholarVerdicts: String?

    enum CodingKeys: String, CodingKey {
        case text, grade, source
        case scholarVerdicts = "scholar_verdicts"
    }
}

/// Where else this answer is available. Derived server-side from the verified
/// citations' sources — never from the model, which would happily claim a
/// YouTube link that does not exist. Every kind is always present so the UI can
/// say "غير متاح" rather than omit a row and leave the reader unsure.
public struct SearchResource: Decodable, Equatable, Identifiable, Sendable {
    public let kind: String
    public let available: Bool
    public let url: String?

    public var id: String { kind }
}

public struct SearchResponse: Decodable, Equatable, Sendable {
    public let answer: String
    public let citations: [SearchCitation]
    public let refused: Bool
    public let mode: String
    // Every structured field is optional with a default, so a response from a
    // backend that predates M5.1 still decodes and the app degrades to the flat
    // answer rather than failing to parse.
    public let summary: String?
    public let ruling: Ruling
    public let scholarAnswers: [ScholarAnswer]
    public let hadith: HadithVerdict?
    public let resources: [SearchResource]

    enum CodingKeys: String, CodingKey {
        case answer, citations, refused, mode, summary, ruling, hadith, resources
        case scholarAnswers = "scholar_answers"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        answer = try c.decode(String.self, forKey: .answer)
        citations = try c.decode([SearchCitation].self, forKey: .citations)
        refused = try c.decode(Bool.self, forKey: .refused)
        mode = try c.decode(String.self, forKey: .mode)
        summary = try c.decodeIfPresent(String.self, forKey: .summary)
        ruling = try c.decodeIfPresent(Ruling.self, forKey: .ruling) ?? Ruling.none
        scholarAnswers = try c.decodeIfPresent([ScholarAnswer].self, forKey: .scholarAnswers) ?? []
        hadith = try c.decodeIfPresent(HadithVerdict.self, forKey: .hadith)
        resources = try c.decodeIfPresent([SearchResource].self, forKey: .resources) ?? []
    }

    /// Memberwise init for tests and previews — the decoder above replaces the
    /// synthesized one.
    public init(
        answer: String,
        citations: [SearchCitation] = [],
        refused: Bool = false,
        mode: String = "fatwa",
        summary: String? = nil,
        ruling: Ruling = .none,
        scholarAnswers: [ScholarAnswer] = [],
        hadith: HadithVerdict? = nil,
        resources: [SearchResource] = []
    ) {
        self.answer = answer
        self.citations = citations
        self.refused = refused
        self.mode = mode
        self.summary = summary
        self.ruling = ruling
        self.scholarAnswers = scholarAnswers
        self.hadith = hadith
        self.resources = resources
    }
}
