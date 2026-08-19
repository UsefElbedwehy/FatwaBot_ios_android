import ContentKit
import CoreKit
import Foundation
import Observation

/// Collections browser + reading state (docs/features/hadith-collections.md).
/// Entries auto-mark as read on navigation — no explicit action required.
/// Pure over injected store; content loading from ContentKit is a thin
/// wrapper kept separate so navigation/progress logic is unit-testable.
@MainActor
@Observable
public final class HadithViewModel {
    public private(set) var collections: [HadithCollectionSummary] = []
    public private(set) var isLoadingCollections = false
    public private(set) var currentDetail: HadithCollectionDetail?
    public private(set) var currentIndex: Int = 0

    private var progress: [String: HadithProgress]
    private let contentService: ContentService?
    private let store: HadithStoring
    private let haptics: HapticsProviding
    private let activityEvents: ActivityEventRecording

    public init(
        contentService: ContentService? = nil,
        store: HadithStoring,
        haptics: HapticsProviding = NoopHaptics(),
        activityEvents: ActivityEventRecording = NoopActivityEventRecording()
    ) {
        self.contentService = contentService
        self.store = store
        self.haptics = haptics
        self.activityEvents = activityEvents
        self.progress = store.loadProgress()
    }

    public func loadCollections(locale: String) async {
        guard let contentService else { return }
        isLoadingCollections = true
        collections = await contentService.hadithCollections(locale: locale)
        isLoadingCollections = false
    }

    /// Opens a collection, resuming at the last-read entry if one exists.
    public func openCollection(slug: String, locale: String) async {
        guard let contentService else { return }
        guard let detail = await contentService.hadithDetail(slug: slug, locale: locale) else { return }
        setDetail(detail)
    }

    /// Test-only seam so navigation logic is testable without a live
    /// ContentService (mirrors AzkarViewModel.startSession taking items directly).
    func setDetail(_ detail: HadithCollectionDetail) {
        currentDetail = detail
        if let last = progress[detail.slug]?.lastReadNumber,
           let index = detail.entries.firstIndex(where: { $0.number == last }) {
            currentIndex = index
        } else {
            currentIndex = 0
        }
        markCurrentRead()
    }

    public var currentEntry: HadithEntry? {
        guard let detail = currentDetail, detail.entries.indices.contains(currentIndex) else { return nil }
        return detail.entries[currentIndex]
    }

    public func readCount(forSlug slug: String) -> Int {
        progress[slug]?.readNumbers.count ?? 0
    }

    public func isCompleted(slug: String, totalEntries: Int) -> Bool {
        totalEntries > 0 && readCount(forSlug: slug) >= totalEntries
    }

    /// Clamps at the last entry — no wraparound, no crash.
    public func next() {
        guard let detail = currentDetail, currentIndex < detail.entries.count - 1 else { return }
        currentIndex += 1
        markCurrentRead()
    }

    /// Clamps at the first entry — no wraparound, no crash.
    public func previous() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        markCurrentRead()
    }

    public func jumpTo(number: Int) {
        guard let detail = currentDetail, let index = detail.entries.firstIndex(where: { $0.number == number }) else { return }
        currentIndex = index
        markCurrentRead()
    }

    /// Records an entry as read because it scrolled into view.
    ///
    /// ## Why this exists alongside `markCurrentRead`
    /// Progress used to advance only through `next()`/`previous()`, because the
    /// reader showed one entry at a time. The collection is now a scrollable
    /// list, so there is no "current" entry to advance to — "read" has to mean
    /// "reached the screen", which is what a list can actually observe.
    ///
    /// This does mean a fast scroll marks several entries at once. That is a
    /// real change in what progress measures, and it is the honest reading of a
    /// list: the alternative — a dwell timer, or an explicit "mark read" control
    /// on every card — either lies in the other direction or puts a chore on a
    /// reading surface.
    ///
    /// Idempotent: the streak event fires only the first time an entry is seen,
    /// so scrolling back up a list does not re-award anything.
    ///
    /// No haptic, unlike `markCurrentRead`. There, one tick acknowledged one
    /// deliberate tap on "next"; here the trigger is scrolling, and a tick per
    /// card arriving on screen would make the device buzz continuously for the
    /// length of a flick.
    public func markRead(number: Int) {
        guard let detail = currentDetail else { return }
        var record = progress[detail.slug] ?? HadithProgress()
        let (isNewlyRead, _) = record.readNumbers.insert(number)
        guard isNewlyRead else { return }
        record.lastReadNumber = number
        progress[detail.slug] = record
        store.saveProgress(progress)
        activityEvents.record(eventType: "hadith_entry_read", metadata: ["collection": detail.slug])
    }

    private func markCurrentRead() {
        guard let detail = currentDetail, let entry = currentEntry else { return }
        var record = progress[detail.slug] ?? HadithProgress()
        let (isNewlyRead, _) = record.readNumbers.insert(entry.number)
        record.lastReadNumber = entry.number
        progress[detail.slug] = record
        store.saveProgress(progress)
        if isNewlyRead {
            activityEvents.record(eventType: "hadith_entry_read", metadata: ["collection": detail.slug])
            haptics.tick()
        }
    }
}
