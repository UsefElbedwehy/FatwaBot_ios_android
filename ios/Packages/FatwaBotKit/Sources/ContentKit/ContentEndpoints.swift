import Foundation
import NetworkingKit

/// Content endpoint catalog. Lives in ContentKit (not NetworkingKit's shared
/// Endpoints.swift) because these reference ContentKit's response types, and
/// NetworkingKit must not depend back on ContentKit.
enum ContentEndpoints {
    static func azkar(sinceVersion: Int?) -> Endpoint<AzkarCollection> {
        Endpoint(path: "v1/content/azkar", query: sinceQuery(sinceVersion))
    }

    static func duas(sinceVersion: Int?) -> Endpoint<DuaCollection> {
        Endpoint(path: "v1/content/duas", query: sinceQuery(sinceVersion))
    }

    static let hadithCollections = Endpoint<HadithCollectionsResponse>(path: "v1/content/hadith-collections")

    static func hadithDetail(slug: String, sinceVersion: Int?) -> Endpoint<HadithCollectionDetail> {
        Endpoint(path: "v1/content/hadith-collections/\(slug)", query: sinceQuery(sinceVersion))
    }

    static func wirdTemplates(sinceVersion: Int?) -> Endpoint<WirdTemplatesCollection> {
        Endpoint(path: "v1/content/wird-templates", query: sinceQuery(sinceVersion))
    }

    private static func sinceQuery(_ version: Int?) -> [URLQueryItem] {
        guard let version else { return [] }
        return [URLQueryItem(name: "since_version", value: String(version))]
    }
}
