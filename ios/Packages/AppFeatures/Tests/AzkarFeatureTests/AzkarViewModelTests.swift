import XCTest
import ContentKit
import CoreKit
@testable import AzkarFeature

final class AzkarViewModelTests: XCTestCase {
    final class InMemoryStore: AzkarStoring, @unchecked Sendable {
        var session: AzkarSessionState?
        var completions: [AzkarCompletionRecord] = []
        func loadSession() -> AzkarSessionState? { session }
        func saveSession(_ session: AzkarSessionState?) { self.session = session }
        func loadCompletions() -> [AzkarCompletionRecord] { completions }
        func recordCompletion(_ record: AzkarCompletionRecord) { completions.append(record) }
    }

    final class SpyActivityEvents: ActivityEventRecording, @unchecked Sendable {
        var recorded: [(eventType: String, metadata: [String: String])] = []
        func record(eventType: String, metadata: [String: String]) { recorded.append((eventType, metadata)) }
    }

    private func item(_ id: String, repeatCount: Int) -> AzkarItem {
        AzkarItem(
            id: id, sortOrder: 0, arabicText: "ذكر \(id)", transliteration: nil,
            translation: nil, virtueNote: nil, source: "", repeatCount: repeatCount
        )
    }

    private let fixedNow = Date(timeIntervalSince1970: 1_774_000_000)

    @MainActor
    func testAutoAdvanceAtExactlyRepeatCountReachesNextItemNotOvershooting() {
        let items = [item("a", repeatCount: 3), item("b", repeatCount: 1)]
        let viewModel = AzkarViewModel(store: InMemoryStore(), now: { [fixedNow] in fixedNow })
        viewModel.startSession(categoryId: "cat1", items: items)

        viewModel.tick() // 1
        viewModel.tick() // 2
        XCTAssertEqual(viewModel.currentItemIndex, 0)
        XCTAssertEqual(viewModel.currentItemCount, 2)

        viewModel.tick() // 3 -> reaches repeatCount exactly -> advances
        XCTAssertEqual(viewModel.currentItemIndex, 1, "must advance at exactly N, not N+1")
        XCTAssertEqual(viewModel.currentItemCount, 0)
    }

    @MainActor
    func testResumeMidSessionSameDayRestoresExactPosition() {
        let store = InMemoryStore()
        let items = [item("a", repeatCount: 5), item("b", repeatCount: 5)]
        let first = AzkarViewModel(store: store, now: { [fixedNow] in fixedNow })
        first.startSession(categoryId: "cat1", items: items)
        first.tick()
        first.tick() // count = 2, still on item 0

        // Simulate app restart: brand-new ViewModel, same store, same day.
        let second = AzkarViewModel(store: store, now: { [fixedNow] in fixedNow })
        second.startSession(categoryId: "cat1", items: items)

        XCTAssertEqual(second.currentItemIndex, 0)
        XCTAssertEqual(second.currentItemCount, 2, "must restore the exact in-progress count")
    }

    @MainActor
    func testResumeDoesNotApplyAcrossDifferentCategoryOrDay() {
        let store = InMemoryStore()
        let items = [item("a", repeatCount: 5)]
        let first = AzkarViewModel(store: store, now: { [fixedNow] in fixedNow })
        first.startSession(categoryId: "cat1", items: items)
        first.tick()

        // Different category: must not resume cat1's progress.
        let second = AzkarViewModel(store: store, now: { [fixedNow] in fixedNow })
        second.startSession(categoryId: "cat2", items: items)
        XCTAssertEqual(second.currentItemCount, 0)

        // Same category, next day: must not resume either.
        let nextDay = fixedNow.addingTimeInterval(86_400 * 2) // safely past day boundary
        let third = AzkarViewModel(store: store, now: { nextDay })
        third.startSession(categoryId: "cat1", items: items)
        XCTAssertEqual(third.currentItemCount, 0, "stale sessions from a previous day must not resume")
    }

    @MainActor
    func testSessionCompletionIsIdempotent() {
        let store = InMemoryStore()
        let items = [item("a", repeatCount: 1)]
        let viewModel = AzkarViewModel(store: store, now: { [fixedNow] in fixedNow })
        viewModel.startSession(categoryId: "cat1", items: items)

        viewModel.tick() // completes the only item -> session complete
        XCTAssertTrue(viewModel.isSessionComplete)
        XCTAssertEqual(store.completions.count, 1)

        viewModel.tick() // must be a no-op: already complete
        viewModel.tick()
        XCTAssertEqual(store.completions.count, 1, "completing twice must not double-record")
        XCTAssertTrue(viewModel.isCompletedToday("cat1"))
    }

    @MainActor
    func testSessionCompletionRecordsAnActivityEventExactlyOnce() {
        let events = SpyActivityEvents()
        let items = [item("a", repeatCount: 1)]
        let viewModel = AzkarViewModel(store: InMemoryStore(), activityEvents: events, now: { [fixedNow] in fixedNow })
        viewModel.startSession(categoryId: "cat1", items: items)

        viewModel.tick() // completes -> should record
        viewModel.tick() // idempotent no-op -> should NOT record again

        XCTAssertEqual(events.recorded.map(\.eventType), ["azkar_completed"])
        XCTAssertEqual(events.recorded.first?.metadata["category_id"], "cat1")
    }

    @MainActor
    func testCompletedTodayLoadsFromExistingHistoryOnInit() {
        let store = InMemoryStore()
        store.completions = [AzkarCompletionRecord(categoryId: "cat1", completedAt: fixedNow)]
        let viewModel = AzkarViewModel(store: store, now: { [fixedNow] in fixedNow })
        XCTAssertTrue(viewModel.isCompletedToday("cat1"))
        XCTAssertFalse(viewModel.isCompletedToday("cat2"))
    }

    @MainActor
    func testProgressReflectsItemIndexOverTotal() {
        let items = [item("a", repeatCount: 1), item("b", repeatCount: 1), item("c", repeatCount: 1)]
        let viewModel = AzkarViewModel(store: InMemoryStore(), now: { [fixedNow] in fixedNow })
        viewModel.startSession(categoryId: "cat1", items: items)
        XCTAssertEqual(viewModel.progress, 0)
        viewModel.tick()
        XCTAssertEqual(viewModel.progress, 1.0 / 3.0, accuracy: 0.001)
    }
}
