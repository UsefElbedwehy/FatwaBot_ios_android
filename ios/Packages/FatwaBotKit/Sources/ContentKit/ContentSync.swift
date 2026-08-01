import Foundation

public extension ContentService {
    /// Pulls every content collection the app renders, so anything published in
    /// the dashboard actually reaches the device.
    ///
    /// ## Why this exists
    /// `ContentService` has had per-collection `refresh*` methods since M2, and
    /// until now **nothing called any of them**. Every install therefore served
    /// its bundled seed JSON forever: the admin content pipeline was write-only,
    /// and a change like the hadith restructure (migration 0025) could never
    /// appear on a device no matter how many times it was published.
    ///
    /// ## Failure policy
    /// Each collection refreshes independently: one unreachable endpoint must
    /// not stop the others, and no failure is fatal — the app is offline-first
    /// and the cached copy is a valid answer.
    ///
    /// Failures are *reported* rather than swallowed, which is the difference
    /// between this and the original. Returning a bare `Bool` made "nothing
    /// changed" and "the request failed" the same value, and that is how a whole
    /// content release went invisible with nothing anywhere saying so.
    ///
    /// Details are refreshed only for collections the server still lists, which
    /// is what prunes content that has been unpublished — a detail fetched for a
    /// collection no longer in the list would resurrect it in the cache.

    /// What a full sync did, so a caller can tell a healthy no-op from a
    /// silently broken one.
    public struct SyncSummary: Equatable, Sendable {
        public internal(set) var updated: [String] = []
        public internal(set) var failed: [String] = []

        public var didUpdate: Bool { !updated.isEmpty }
        public var hasFailures: Bool { !failed.isEmpty }

        public init(updated: [String] = [], failed: [String] = []) {
            self.updated = updated
            self.failed = failed
        }
    }

    @discardableResult
    public func syncAll(locale: String) async -> SyncSummary {
        var summary = SyncSummary()
        func note(_ key: String, _ outcome: RefreshOutcome) {
            switch outcome {
            case .updated: summary.updated.append(key)
            case .failed: summary.failed.append(key)
            case .unchanged: break
            }
        }

        // Collections first: the list decides which details are worth fetching.
        note("hadith-collections", await refreshHadithCollections(locale: locale))

        async let azkar = refreshAzkar(locale: locale)
        async let duas = refreshDuas(locale: locale)
        async let wird = refreshWirdTemplates(locale: locale)
        let (azkarOutcome, duasOutcome, wirdOutcome) = await (azkar, duas, wird)
        note("azkar", azkarOutcome)
        note("duas", duasOutcome)
        note("wird-templates", wirdOutcome)

        for summaryRow in hadithCollections(locale: locale) {
            note("hadith-\(summaryRow.slug)", await refreshHadithDetail(slug: summaryRow.slug, locale: locale))
        }

        return summary
    }
}
