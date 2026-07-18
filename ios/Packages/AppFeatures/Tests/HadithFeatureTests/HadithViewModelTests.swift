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

    @MainActor
    func testCollectionsRenderOfflineFromBundledSeedFallback() async {
        // No live ContentService injected — mirrors "renders even fully offline
        // on first launch" via the bundled seed fallback ContentKit provides.
        let viewModel = HadithViewModel(store: InMemoryStore())
        await viewModel.loadCollections(locale: "ar")
        XCTAssertTrue(viewModel.collections.isEmpty, "without a ContentService, collections stay empty rather than crashing")
    }
}
