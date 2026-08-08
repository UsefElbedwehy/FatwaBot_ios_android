import Foundation

// Server contract models — mirror backend/functions/api/content_types.ts exactly
// (already locale-resolved plain strings; property names match JSON keys so no
// CodingKeys are needed). Also the shape of the bundled seed JSON in Resources/.
//
// Every struct declares an explicit `public init`: Swift's synthesized
// memberwise initializer for a public struct is only `internal`, which would
// make these unconstructible from feature modules (tests, previews, fixtures).

public struct AzkarItem: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let sortOrder: Int
    /// Short name for the dhikr ("شكر الله على رد الروح"), when one exists.
    ///
    /// Optional and expected to stay that way: titling the corpus is reviewed
    /// religious content that lands separately from this plumbing, so the reader
    /// must render an untitled entry correctly for as long as any remain — which
    /// on a cached payload from an older release is forever.
    public let title: String?
    public let arabicText: String
    public let transliteration: String?
    public let translation: String?
    public let virtueNote: String?
    public let source: String
    public let repeatCount: Int

    public init(
        id: String,
        sortOrder: Int,
        title: String? = nil,
        arabicText: String,
        transliteration: String?,
        translation: String?,
        virtueNote: String?,
        source: String,
        repeatCount: Int
    ) {
        self.id = id
        self.sortOrder = sortOrder
        self.title = title
        self.arabicText = arabicText
        self.transliteration = transliteration
        self.translation = translation
        self.virtueNote = virtueNote
        self.source = source
        self.repeatCount = repeatCount
    }

    // Hand-written so `title` decodes as absent rather than failing. Every
    // device holds a cached azkar payload written before this field existed;
    // a synthesized decoder would reject the whole collection and the reader
    // would fall back to bundled seed with no error anywhere saying why.
    private enum CodingKeys: String, CodingKey {
        case id, sortOrder, title, arabicText, transliteration, translation
        case virtueNote, source, repeatCount
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        sortOrder = try c.decode(Int.self, forKey: .sortOrder)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        arabicText = try c.decode(String.self, forKey: .arabicText)
        transliteration = try c.decodeIfPresent(String.self, forKey: .transliteration)
        translation = try c.decodeIfPresent(String.self, forKey: .translation)
        virtueNote = try c.decodeIfPresent(String.self, forKey: .virtueNote)
        source = try c.decode(String.self, forKey: .source)
        repeatCount = try c.decode(Int.self, forKey: .repeatCount)
    }
}

public struct AzkarCategory: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let slug: String
    public let name: String
    public let sortOrder: Int
    public let items: [AzkarItem]

    public init(id: String, slug: String, name: String, sortOrder: Int, items: [AzkarItem]) {
        self.id = id
        self.slug = slug
        self.name = name
        self.sortOrder = sortOrder
        self.items = items
    }
}

public struct AzkarCollection: Codable, Equatable, Sendable {
    public let version: Int
    public let categories: [AzkarCategory]

    public init(version: Int, categories: [AzkarCategory]) {
        self.version = version
        self.categories = categories
    }
}

public struct Dua: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let sortOrder: Int
    public let title: String
    public let arabicText: String
    public let transliteration: String?
    public let translation: String?
    public let source: String

    public init(
        id: String,
        sortOrder: Int,
        title: String,
        arabicText: String,
        transliteration: String?,
        translation: String?,
        source: String
    ) {
        self.id = id
        self.sortOrder = sortOrder
        self.title = title
        self.arabicText = arabicText
        self.transliteration = transliteration
        self.translation = translation
        self.source = source
    }

    /// What to show as the row's heading.
    ///
    /// Hisn al-Muslim — the source of the whole imported library — titles its
    /// *chapters*, not its individual supplications, so every `Dua.title` comes
    /// back empty. Rendering the raw field left every row in the library showing
    /// nothing but "حصن المسلم", one identical line 132 categories deep.
    ///
    /// The opening words of the du'a are how these are actually referred to, so
    /// they make a better heading than a placeholder. Truncation is on a word
    /// boundary to avoid cutting an Arabic word in half.
    public var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return Self.snippet(from: arabicText)
    }

    static func snippet(from text: String, limit: Int = 48) -> String {
        // Strip the recitation marks the corpus wraps verses in, so a snippet
        // starts on the words themselves rather than on punctuation.
        let cleaned = text
            .replacingOccurrences(of: "((", with: "")
            .replacingOccurrences(of: "))", with: "")
            .replacingOccurrences(of: "﴿", with: "")
            .replacingOccurrences(of: "﴾", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count > limit else { return cleaned }
        let prefix = cleaned.prefix(limit)
        guard let lastSpace = prefix.lastIndex(of: " ") else { return String(prefix) + "…" }
        return String(prefix[prefix.startIndex..<lastSpace]) + "…"
    }
}

public struct DuaCategory: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let slug: String
    public let name: String
    public let sortOrder: Int
    public let duas: [Dua]

    public init(id: String, slug: String, name: String, sortOrder: Int, duas: [Dua]) {
        self.id = id
        self.slug = slug
        self.name = name
        self.sortOrder = sortOrder
        self.duas = duas
    }
}

public struct DuaCollection: Codable, Equatable, Sendable {
    public let version: Int
    public let categories: [DuaCategory]

    public init(version: Int, categories: [DuaCategory]) {
        self.version = version
        self.categories = categories
    }
}

public struct HadithCollectionSummary: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let slug: String
    public let name: String
    public let description: String
    public let entryCount: Int

    public init(id: String, slug: String, name: String, description: String, entryCount: Int) {
        self.id = id
        self.slug = slug
        self.name = name
        self.description = description
        self.entryCount = entryCount
    }
}

public struct HadithEntry: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let number: Int
    public let arabicText: String
    public let translation: String?
    public let grading: String
    public let benefitNote: String?
    public let source: String

    public init(
        id: String,
        number: Int,
        arabicText: String,
        translation: String?,
        grading: String,
        benefitNote: String?,
        source: String
    ) {
        self.id = id
        self.number = number
        self.arabicText = arabicText
        self.translation = translation
        self.grading = grading
        self.benefitNote = benefitNote
        self.source = source
    }
}

public struct HadithCollectionDetail: Codable, Equatable, Sendable {
    public let version: Int
    public let slug: String
    public let name: String
    public let description: String
    public let entries: [HadithEntry]

    public init(version: Int, slug: String, name: String, description: String, entries: [HadithEntry]) {
        self.version = version
        self.slug = slug
        self.name = name
        self.description = description
        self.entries = entries
    }
}

public struct WirdTemplate: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let description: String
    public let type: String
    public let defaultTarget: Int
    public let defaultUnit: String
    public let defaultFrequency: String

    public init(
        id: String,
        name: String,
        description: String,
        type: String,
        defaultTarget: Int,
        defaultUnit: String,
        defaultFrequency: String
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.type = type
        self.defaultTarget = defaultTarget
        self.defaultUnit = defaultUnit
        self.defaultFrequency = defaultFrequency
    }
}

public struct WirdTemplatesCollection: Codable, Equatable, Sendable {
    public let version: Int
    public let templates: [WirdTemplate]

    public init(version: Int, templates: [WirdTemplate]) {
        self.version = version
        self.templates = templates
    }
}

struct HadithCollectionsResponse: Codable, Sendable {
    let collections: [HadithCollectionSummary]
}
