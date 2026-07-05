import Foundation

// Server contract models — mirror backend/functions/api/content_types.ts exactly
// (already locale-resolved plain strings; property names match JSON keys so no
// CodingKeys are needed). Also the shape of the bundled seed JSON in Resources/.

public struct AzkarItem: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let sortOrder: Int
    public let arabicText: String
    public let transliteration: String?
    public let translation: String?
    public let virtueNote: String?
    public let source: String
    public let repeatCount: Int
}

public struct AzkarCategory: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let slug: String
    public let name: String
    public let sortOrder: Int
    public let items: [AzkarItem]
}

public struct AzkarCollection: Codable, Equatable, Sendable {
    public let version: Int
    public let categories: [AzkarCategory]
}

public struct Dua: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let sortOrder: Int
    public let title: String
    public let arabicText: String
    public let transliteration: String?
    public let translation: String?
    public let source: String
}

public struct DuaCategory: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let slug: String
    public let name: String
    public let sortOrder: Int
    public let duas: [Dua]
}

public struct DuaCollection: Codable, Equatable, Sendable {
    public let version: Int
    public let categories: [DuaCategory]
}

public struct HadithCollectionSummary: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let slug: String
    public let name: String
    public let description: String
    public let entryCount: Int
}

public struct HadithEntry: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let number: Int
    public let arabicText: String
    public let translation: String?
    public let grading: String
    public let benefitNote: String?
    public let source: String
}

public struct HadithCollectionDetail: Codable, Equatable, Sendable {
    public let version: Int
    public let slug: String
    public let name: String
    public let description: String
    public let entries: [HadithEntry]
}

public struct WirdTemplate: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let description: String
    public let type: String
    public let defaultTarget: Int
    public let defaultUnit: String
    public let defaultFrequency: String
}

public struct WirdTemplatesCollection: Codable, Equatable, Sendable {
    public let version: Int
    public let templates: [WirdTemplate]
}

struct HadithCollectionsResponse: Codable, Sendable {
    let collections: [HadithCollectionSummary]
}
