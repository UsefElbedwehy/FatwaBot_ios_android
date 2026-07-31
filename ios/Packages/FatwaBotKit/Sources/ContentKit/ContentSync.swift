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
    /// Each collection refreshes independently and swallows its own failure —
    /// that is already each `refresh*` method's contract. One unreachable
    /// endpoint must not stop the others, and none of them may surface an error:
    /// the app is offline-first, and the bundled seed is a valid answer.
    ///
    /// Details are refreshed only for collections the server still lists, which
    /// is what prunes content that has been unpublished — a detail fetched for a
    /// collection no longer in the list would resurrect it in the cache.
    @discardableResult
    func syncAll(locale: String) async -> Bool {
        // Collections first: the list decides which details are worth fetching.
        let collectionsChanged = await refreshHadithCollections(locale: locale)

        async let azkar = refreshAzkar(locale: locale)
        async let duas = refreshDuas(locale: locale)
        async let wird = refreshWirdTemplates(locale: locale)
        let (azkarChanged, duasChanged, wirdChanged) = await (azkar, duas, wird)

        var detailChanged = false
        for summary in hadithCollections(locale: locale) {
            if await refreshHadithDetail(slug: summary.slug, locale: locale) {
                detailChanged = true
            }
        }

        return collectionsChanged || azkarChanged || duasChanged || wirdChanged || detailChanged
    }
}
