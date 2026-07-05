import CoreKit
import Foundation
import NetworkingKit

/// Content sync (docs/features/content-pipeline.md). Mirrors ConfigService's
/// offline-first shape: `current(locale:)` always resolves synchronously
/// (cache → bundled seed → nil), `refresh` fetches deltas and is silent on
/// failure — content stays fully usable with zero connectivity.
public actor ContentService {
    private let store: ContentFileStore
    private let client: APIClientProtocol

    private var cachedAzkar: [String: AzkarCollection] = [:]
    private var cachedDuas: [String: DuaCollection] = [:]
    private var cachedHadithSummaries: [String: [HadithCollectionSummary]] = [:]
    private var cachedHadithDetail: [String: HadithCollectionDetail] = [:] // key: "\(slug)_\(locale)"
    private var cachedWird: [String: WirdTemplatesCollection] = [:]

    public init(store: ContentFileStore, client: APIClientProtocol) {
        self.store = store
        self.client = client
    }

    // MARK: - Synchronous reads (cache → bundled seed)

    public func azkar(locale: String) -> AzkarCollection? {
        if let cached = cachedAzkar[locale] { return cached }
        let loaded = store.load(AzkarCollection.self, key: "azkar.\(locale)")
        cachedAzkar[locale] = loaded
        return loaded
    }

    public func duas(locale: String) -> DuaCollection? {
        if let cached = cachedDuas[locale] { return cached }
        let loaded = store.load(DuaCollection.self, key: "duas.\(locale)")
        cachedDuas[locale] = loaded
        return loaded
    }

    public func hadithCollections(locale: String) -> [HadithCollectionSummary] {
        if let cached = cachedHadithSummaries[locale] { return cached }
        let loaded = store.load(HadithCollectionsResponse.self, key: "hadith-collections.\(locale)")?.collections ?? []
        cachedHadithSummaries[locale] = loaded
        return loaded
    }

    public func hadithDetail(slug: String, locale: String) -> HadithCollectionDetail? {
        let key = "\(slug)_\(locale)"
        if let cached = cachedHadithDetail[key] { return cached }
        let loaded = store.load(HadithCollectionDetail.self, key: "hadith-\(slug).\(locale)")
        cachedHadithDetail[key] = loaded
        return loaded
    }

    public func wirdTemplates(locale: String) -> WirdTemplatesCollection? {
        if let cached = cachedWird[locale] { return cached }
        let loaded = store.load(WirdTemplatesCollection.self, key: "wird-templates.\(locale)")
        cachedWird[locale] = loaded
        return loaded
    }

    // MARK: - Refresh (per-collection independent failure)

    @discardableResult
    public func refreshAzkar(locale: String) async -> Bool {
        guard let fresh = try? await client.get(
            ContentEndpoints.azkar(sinceVersion: azkar(locale: locale)?.version)
        ) else { return false }
        guard fresh != cachedAzkar[locale] else { return false }
        cachedAzkar[locale] = fresh
        store.save(fresh, key: "azkar.\(locale)")
        return true
    }

    @discardableResult
    public func refreshDuas(locale: String) async -> Bool {
        guard let fresh = try? await client.get(
            ContentEndpoints.duas(sinceVersion: duas(locale: locale)?.version)
        ) else { return false }
        guard fresh != cachedDuas[locale] else { return false }
        cachedDuas[locale] = fresh
        store.save(fresh, key: "duas.\(locale)")
        return true
    }

    @discardableResult
    public func refreshHadithCollections(locale: String) async -> Bool {
        guard let fresh = try? await client.get(ContentEndpoints.hadithCollections) else { return false }
        guard fresh.collections != cachedHadithSummaries[locale] else { return false }
        cachedHadithSummaries[locale] = fresh.collections
        store.save(fresh, key: "hadith-collections.\(locale)")
        return true
    }

    @discardableResult
    public func refreshHadithDetail(slug: String, locale: String) async -> Bool {
        let key = "\(slug)_\(locale)"
        guard let fresh = try? await client.get(
            ContentEndpoints.hadithDetail(slug: slug, sinceVersion: hadithDetail(slug: slug, locale: locale)?.version)
        ) else { return false }
        guard fresh != cachedHadithDetail[key] else { return false }
        cachedHadithDetail[key] = fresh
        store.save(fresh, key: "hadith-\(slug).\(locale)")
        return true
    }

    @discardableResult
    public func refreshWirdTemplates(locale: String) async -> Bool {
        guard let fresh = try? await client.get(
            ContentEndpoints.wirdTemplates(sinceVersion: wirdTemplates(locale: locale)?.version)
        ) else { return false }
        guard fresh != cachedWird[locale] else { return false }
        cachedWird[locale] = fresh
        store.save(fresh, key: "wird-templates.\(locale)")
        return true
    }
}
