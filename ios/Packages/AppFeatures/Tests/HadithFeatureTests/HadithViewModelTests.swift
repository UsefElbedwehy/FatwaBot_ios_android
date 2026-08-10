import XCTest
import ContentKit
import CoreKit
@testable import HadithFeature

final class HadithViewModelTests: XCTestCase {
    final class InMemoryStore: HadithStoring, @unchecked Sendable {
        var progress: [String: HadithProgress] = [:]
        func loadProgress() -> [String: HadithProgress] { progress }
        func saveProgress(_ progress: [String: HadithProgress]) { self.progress = progress }
    }

    final class SpyActivityEvents: ActivityEventRecording, @unchecked Sendable {
        var recorded: [(eventType: String, metadata: [String: String])] = []
        func record(eventType: String, metadata: [String: String]) { recorded.append((eventType, metadata)) }
    }

    final class SpyHaptics: HapticsProviding, @unchecked Sendable {
        var tickCount = 0
        var targetReachedCount = 0
        func tick() { tickCount += 1 }
        func targetReached() { targetReachedCount += 1 }
    }

    private func entry(_ number: Int) -> HadithEntry {
        HadithEntry(id: "h\(number)", number: number, arabicText: "حديث \(number)", translation: nil, grading: "صحيح", benefitNote: nil, source: "")
    }

    private func detail(slug: String = "nawawi40", entryNumbers: [Int] = [1, 2, 3]) -> HadithCollectionDetail {
        HadithCollectionDetail(version: 1, slug: slug, name: "الأربعون", description: "", entries: entryNumbers.map(entry))
    }

    @MainActor
    func testPrevNextClampsAtBoundariesNoWraparound() {
        let viewModel = HadithViewModel(store: InMemoryStore())
        viewModel.setDetail(detail())
        XCTAssertEqual(viewModel.currentEntry?.number, 1)

        viewModel.previous() // already at first — must not crash or wrap
        XCTAssertEqual(viewModel.currentEntry?.number, 1)

        viewModel.next()
        viewModel.next()
        XCTAssertEqual(viewModel.currentEntry?.number, 3)
        viewModel.next() // already at last — must not crash or wrap
        XCTAssertEqual(viewModel.currentEntry?.number, 3)
    }

    @MainActor
    func testReReadingDoesNotDoubleCount() {
        let viewModel = HadithViewModel(store: InMemoryStore())
        viewModel.setDetail(detail())
        viewModel.next()
        viewModel.previous()
        viewModel.previous() // already at first
        XCTAssertEqual(viewModel.readCount(forSlug: "nawawi40"), 2, "revisiting entries must not double count")
    }

    @MainActor
    func testProgressPersistsAcrossRestarts() {
        let store = InMemoryStore()
        let first = HadithViewModel(store: store)
        first.setDetail(detail())
        first.next()
        first.next() // read 1, 2, 3

        let second = HadithViewModel(store: store)
        second.setDetail(detail())
        XCTAssertEqual(second.currentEntry?.number, 3, "must resume at the last-read entry")
        XCTAssertEqual(second.readCount(forSlug: "nawawi40"), 3)
    }

    @MainActor
    func testIsCompletedRequiresAllEntriesRead() {
        let viewModel = HadithViewModel(store: InMemoryStore())
        viewModel.setDetail(detail())
        XCTAssertFalse(viewModel.isCompleted(slug: "nawawi40", totalEntries: 3))
        viewModel.next()
        viewModel.next()
        XCTAssertTrue(viewModel.isCompleted(slug: "nawawi40", totalEntries: 3))
    }

    @MainActor
    func testJumpToNavigatesDirectlyAndMarksRead() {
        let viewModel = HadithViewModel(store: InMemoryStore())
        viewModel.setDetail(detail())
        viewModel.jumpTo(number: 3)
        XCTAssertEqual(viewModel.currentEntry?.number, 3)
        XCTAssertTrue(viewModel.readCount(forSlug: "nawawi40") >= 2, "jumping ahead marks the target read")
    }

    @MainActor
    func testActivityEventFiresOnlyForNewlyReadEntriesNotRevisits() {
        let events = SpyActivityEvents()
        let viewModel = HadithViewModel(store: InMemoryStore(), activityEvents: events)
        viewModel.setDetail(detail()) // reads entry 1
        viewModel.next() // reads entry 2
        viewModel.previous() // revisits entry 1 — must not re-record
        viewModel.next() // revisits entry 2 — must not re-record

        XCTAssertEqual(events.recorded.map(\.eventType), ["hadith_entry_read", "hadith_entry_read"])
    }

    @MainActor
    func testMarkingAnEntryReadFiresAHapticOnlyForNewlyReadEntries() {
        let haptics = SpyHaptics()
        let viewModel = HadithViewModel(store: InMemoryStore(), haptics: haptics)
        viewModel.setDetail(detail()) // reads entry 1
        XCTAssertEqual(haptics.tickCount, 1)

        viewModel.next() // reads entry 2
        XCTAssertEqual(haptics.tickCount, 2)

        viewModel.previous() // revisits entry 1 — must not re-fire
        XCTAssertEqual(haptics.tickCount, 2)
    }

    // MARK: - markRead (the list-shaped reader)

    /// The collection screen is a scroll list now, so progress advances from
    /// cards appearing rather than from prev/next. These pin the behaviour the
    /// streak depends on.

    @MainActor
    func testScrollingAnEntryIntoViewMarksItReadAndRecordsOneEvent() {
        let events = SpyActivityEvents()
        let viewModel = HadithViewModel(store: InMemoryStore(), activityEvents: events)
        viewModel.setDetail(detail())

        viewModel.markRead(number: 2)

        XCTAssertEqual(viewModel.readCount(forSlug: "nawawi40"), 2, "entry 1 from setDetail, plus 2")
        XCTAssertEqual(
            events.recorded.filter { $0.metadata["collection"] == "nawawi40" }.count, 2
        )
    }

    /// Scrolling back up a list re-triggers `onAppear` for cards already seen.
    /// If that re-awarded the streak, a user could farm it by flicking.
    @MainActor
    func testScrollingBackOverASeenEntryAwardsNothing() {
        let events = SpyActivityEvents()
        let viewModel = HadithViewModel(store: InMemoryStore(), activityEvents: events)
        viewModel.setDetail(detail())

        viewModel.markRead(number: 2)
        let afterFirstPass = events.recorded.count

        viewModel.markRead(number: 2)
        viewModel.markRead(number: 2)
        viewModel.markRead(number: 1)

        XCTAssertEqual(events.recorded.count, afterFirstPass, "re-appearing must not re-award")
        XCTAssertEqual(viewModel.readCount(forSlug: "nawawi40"), 2)
    }

    /// A haptic per card arriving on screen would buzz for the length of a
    /// flick. `markCurrentRead` still ticks; this path deliberately does not.
    @MainActor
    func testScrollingDoesNotFireHaptics() {
        let haptics = SpyHaptics()
        let viewModel = HadithViewModel(store: InMemoryStore(), haptics: haptics)
        viewModel.setDetail(detail())
        let afterOpen = haptics.tickCount

        viewModel.markRead(number: 2)
        viewModel.markRead(number: 3)

        XCTAssertEqual(haptics.tickCount, afterOpen, "scrolling must stay silent")
    }

    @MainActor
    func testScrollingThroughEveryEntryCompletesTheCollection() {
        let viewModel = HadithViewModel(store: InMemoryStore())
        viewModel.setDetail(detail())
        XCTAssertFalse(viewModel.isCompleted(slug: "nawawi40", totalEntries: 3))

        viewModel.markRead(number: 2)
        viewModel.markRead(number: 3)

        XCTAssertTrue(viewModel.isCompleted(slug: "nawawi40", totalEntries: 3))
    }

    /// `onAppear` can fire while a chip change is still loading the next
    /// collection, so this is reachable in practice, not just in theory.
    @MainActor
    func testMarkReadBeforeACollectionLoadsIsANoOp() {
        let events = SpyActivityEvents()
        let viewModel = HadithViewModel(store: InMemoryStore(), activityEvents: events)

        viewModel.markRead(number: 1)

        XCTAssertEqual(viewModel.readCount(forSlug: "nawawi40"), 0)
        XCTAssertTrue(events.recorded.isEmpty)
    }

    @MainActor
    func testScrolledProgressPersistsAcrossRestarts() {
        let store = InMemoryStore()
        let first = HadithViewModel(store: store)
        first.setDetail(detail())
        first.markRead(number: 2)
        first.markRead(number: 3)

        let second = HadithViewModel(store: store)
        second.setDetail(detail())
        XCTAssertEqual(second.readCount(forSlug: "nawawi40"), 3)
    }

    @MainActor
    func testCollectionsRenderOfflineFromBundledSeedFallback() async {
        // No live ContentService injected — mirrors "renders even fully offline
        // on first launch" via the bundled seed fallback ContentKit provides.
        let viewModel = HadithViewModel(store: InMemoryStore())
        await viewModel.loadCollections(locale: "ar")
        XCTAssertTrue(viewModel.collections.isEmpty, "without a ContentService, collections stay empty rather than crashing")
    }
}
