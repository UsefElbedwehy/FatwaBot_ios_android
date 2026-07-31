import CoreKit
import Foundation
import OSLog
import NetworkingKit

/// Content sync (docs/features/content-pipeline.md). Mirrors ConfigService's
/// offline-first shape: `current(locale:)` always resolves synchronously
/// (cache → bundled seed → nil), `refresh` fetches deltas and is silent on
/// failure — content stays fully usable with zero connectivity.
public actor ContentService {
    private let logger = Logger(subsystem: "com.fatwabot.app", category: "content-sync")
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

    /// Why a refresh did not change anything — the distinction `try?` erased.
    ///
    /// Every `refresh*` used to return `false` for both "the server had nothing
    /// new" and "the request failed", which made a broken sync indistinguishable
    /// from a healthy one. That is how an entire content release went invisible:
    /// the app kept serving a stale cache and nothing, anywhere, said so.
    ///
    /// Failures are still non-fatal — the app is offline-first and the cached
    /// copy is a valid answer — but they are now recorded and logged rather than
    /// swallowed.
    public enum RefreshOutcome: Equatable, Sendable {
        case updated
        case unchanged
        case failed(String)

        public var didUpdate: Bool { self == .updated }
        public var isFailure: Bool { if case .failed = self { return true }; return false }
    }

    /// Last failure per content key, for diagnostics. Cleared on success.
    public private(set) var lastFailures: [String: String] = [:]

    private func record(_ key: String, _ outcome: RefreshOutcome) -> RefreshOutcome {
        if case let .failed(message) = outcome {
            lastFailures[key] = message
            logger.error("content refresh failed for \(key, privacy: .public): \(message, privacy: .public)")
        } else {
            lastFailures.removeValue(forKey: key)
        }
        return outcome
    }

    /// Runs one fetch, converting a thrown error into an observable outcome.
    private func refresh<T>(
        key: String,
        endpoint: Endpoint<T>,
        isUnchanged: (T) -> Bool,
        apply: (T) -> Void
    ) async -> RefreshOutcome {
        do {
            let fresh = try await client.get(endpoint)
            if isUnchanged(fresh) { return record(key, .unchanged) }
            apply(fresh)
            return record(key, .updated)
        } catch {
            return record(key, .failed(String(describing: error)))
        }
    }

    @discardableResult
    public func refreshAzkar(locale: String) async -> RefreshOutcome {
        await refresh(
            key: "azkar.\(locale)",
            endpoint: ContentEndpoints.azkar(sinceVersion: azkar(locale: locale)?.version),
            isUnchanged: { $0 == self.cachedAzkar[locale] },
            apply: { fresh in
                self.cachedAzkar[locale] = fresh
                self.store.save(fresh, key: "azkar.\(locale)")
            }
        )
    }

    @discardableResult
    public func refreshDuas(locale: String) async -> RefreshOutcome {
        await refresh(
            key: "duas.\(locale)",
            endpoint: ContentEndpoints.duas(sinceVersion: duas(locale: locale)?.version),
            isUnchanged: { $0 == self.cachedDuas[locale] },
            apply: { fresh in
                self.cachedDuas[locale] = fresh
                self.store.save(fresh, key: "duas.\(locale)")
            }
        )
    }

    @discardableResult
    public func refreshHadithCollections(locale: String) async -> RefreshOutcome {
        await refresh(
            key: "hadith-collections.\(locale)",
            endpoint: ContentEndpoints.hadithCollections,
            isUnchanged: { $0.collections == self.cachedHadithSummaries[locale] },
            apply: { fresh in
                self.cachedHadithSummaries[locale] = fresh.collections
                self.store.save(fresh, key: "hadith-collections.\(locale)")
            }
        )
    }

    @discardableResult
    public func refreshHadithDetail(slug: String, locale: String) async -> RefreshOutcome {
        let cacheKey = "\(slug)_\(locale)"
        return await refresh(
            key: "hadith-\(slug).\(locale)",
            endpoint: ContentEndpoints.hadithDetail(
                slug: slug,
                sinceVersion: hadithDetail(slug: slug, locale: locale)?.version
            ),
            isUnchanged: { $0 == self.cachedHadithDetail[cacheKey] },
            apply: { fresh in
                self.cachedHadithDetail[cacheKey] = fresh
                self.store.save(fresh, key: "hadith-\(slug).\(locale)")
            }
        )
    }

    @discardableResult
    public func refreshWirdTemplates(locale: String) async -> RefreshOutcome {
        await refresh(
            key: "wird-templates.\(locale)",
            endpoint: ContentEndpoints.wirdTemplates(sinceVersion: wirdTemplates(locale: locale)?.version),
            isUnchanged: { $0 == self.cachedWird[locale] },
            apply: { fresh in
                self.cachedWird[locale] = fresh
                self.store.save(fresh, key: "wird-templates.\(locale)")
            }
        )
    }
}
