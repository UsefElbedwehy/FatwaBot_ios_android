import CoreKit
import XCTest
@testable import AwradFeature

/// The notification answer writes the same state the UI writes, from a process
/// where no view model exists. These tests are the guard on that equivalence —
/// the failure mode they exist to prevent (a day reported complete whose per-wird
/// counts don't support it) is silent and permanently inflates the Journey stats.
final class WirdCompletionResponderTests: XCTestCase {
    final class InMemoryStore: WirdStoring, @unchecked Sendable {
        var wirds: [Wird] = []
        var progress: [WirdDailyProgress] = []
        var completions: [WirdDayCompletionRecord] = []
        func loadWirds() -> [Wird] { wirds }
        func saveWirds(_ wirds: [Wird]) { self.wirds = wirds }
        func loadProgress() -> [WirdDailyProgress] { progress }
        func saveProgress(_ progress: [WirdDailyProgress]) { self.progress = progress }
        func loadDayCompletions() -> [WirdDayCompletionRecord] { completions }
        func recordDayCompletion(_ record: WirdDayCompletionRecord) { completions.append(record) }
    }

    final class SpyActivityEvents: ActivityEventRecording, @unchecked Sendable {
        var recorded: [(eventType: String, metadata: [String: String])] = []
        func record(eventType: String, metadata: [String: String]) { recorded.append((eventType, metadata)) }
        var types: [String] { recorded.map(\.eventType) }
    }

    private let fixedNow = Date(timeIntervalSince1970: 1_774_000_000)
    private let utcCalendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    private func wird(id: String, name: String = "ورد", target: Int, archived: Bool = false) -> Wird {
        Wird(
            id: id, name: name, type: "dhikr", target: target, unit: "times", frequency: "daily",
            createdAt: Date(timeIntervalSince1970: 1_770_000_000),
            archivedAt: archived ? Date(timeIntervalSince1970: 1_773_000_000) : nil
        )
    }

    private func makeResponder(
        store: WirdStoring, events: ActivityEventRecording = NoopActivityEventRecording()
    ) -> WirdCompletionResponder {
        let time = fixedNow
        return WirdCompletionResponder(store: store, activityEvents: events, now: { time }, calendar: utcCalendar)
    }

    private var todayKey: String { AwradViewModel.dateKey(for: fixedNow, calendar: utcCalendar) }

    // MARK: - Bringing the wird to target

    func testAnswerRaisesCountToExactlyTheTarget() {
        let store = InMemoryStore()
        store.wirds = [wird(id: "a", target: 33)]
        let outcome = makeResponder(store: store).answerCompleted(wirdId: "a")

        XCTAssertTrue(outcome.ticked)
        XCTAssertEqual(store.progress.count, 1)
        XCTAssertEqual(store.progress[0].count, 33, "must land on the target, not above it")
        XCTAssertEqual(store.progress[0].dateKey, todayKey)
    }

    func testAnswerTopsUpAPartiallyDoneWirdRatherThanAddingATarget() {
        let store = InMemoryStore()
        store.wirds = [wird(id: "a", target: 100)]
        store.progress = [WirdDailyProgress(wirdId: "a", dateKey: todayKey, count: 40)]

        makeResponder(store: store).answerCompleted(wirdId: "a")

        XCTAssertEqual(store.progress[0].count, 100, "40 + 100 would be the bug")
    }

    func testAnswerLeavesYesterdaysProgressAlone() {
        let store = InMemoryStore()
        store.wirds = [wird(id: "a", target: 10)]
        store.progress = [WirdDailyProgress(wirdId: "a", dateKey: "2000-01-01", count: 7)]

        makeResponder(store: store).answerCompleted(wirdId: "a")

        XCTAssertEqual(store.progress.count, 2)
        XCTAssertEqual(store.progress.first { $0.dateKey == "2000-01-01" }?.count, 7)
        XCTAssertEqual(store.progress.first { $0.dateKey == todayKey }?.count, 10)
    }

    // MARK: - Idempotency

    func testRepeatedAnswersDoNotDoubleCountOrDoubleRecord() {
        let store = InMemoryStore()
        let events = SpyActivityEvents()
        store.wirds = [wird(id: "a", target: 33)]
        let responder = makeResponder(store: store, events: events)

        let first = responder.answerCompleted(wirdId: "a")
        let second = responder.answerCompleted(wirdId: "a")
        let third = responder.answerCompleted(wirdId: "a")

        XCTAssertTrue(first.ticked)
        XCTAssertFalse(second.ticked, "a double-tap must not tick again")
        XCTAssertFalse(third.ticked)
        XCTAssertEqual(store.progress[0].count, 33)
        XCTAssertEqual(events.types.filter { $0 == "wird_ticked" }.count, 1)
        XCTAssertEqual(store.completions.count, 1)
        XCTAssertTrue(first.dayCompleted)
        XCTAssertFalse(second.dayCompleted, "day completion is recorded once")
    }

    func testAnsweringAWirdAlreadyPastItsTargetIsANoOp() {
        let store = InMemoryStore()
        let events = SpyActivityEvents()
        store.wirds = [wird(id: "a", target: 10)]
        store.progress = [WirdDailyProgress(wirdId: "a", dateKey: todayKey, count: 25)]

        let outcome = makeResponder(store: store, events: events).answerCompleted(wirdId: "a")

        XCTAssertFalse(outcome.ticked)
        XCTAssertEqual(store.progress[0].count, 25, "over-counting from the UI must not be clawed back")
        XCTAssertFalse(events.types.contains("wird_ticked"))
    }

    // MARK: - Day completion honesty

    func testAnsweringTheLastOutstandingWirdRecordsDayCompletion() {
        let store = InMemoryStore()
        let events = SpyActivityEvents()
        store.wirds = [wird(id: "a", target: 3), wird(id: "b", target: 5)]
        store.progress = [WirdDailyProgress(wirdId: "a", dateKey: todayKey, count: 3)]

        let outcome = makeResponder(store: store, events: events).answerCompleted(wirdId: "b")

        XCTAssertTrue(outcome.dayCompleted)
        XCTAssertEqual(store.completions.map(\.dateKey), [todayKey])
        XCTAssertEqual(events.types, ["wird_ticked", "wird_day_completed"])
    }

    func testAnsweringOneOfSeveralDoesNotRecordDayCompletion() {
        let store = InMemoryStore()
        let events = SpyActivityEvents()
        store.wirds = [wird(id: "a", target: 3), wird(id: "b", target: 5)]

        let outcome = makeResponder(store: store, events: events).answerCompleted(wirdId: "a")

        XCTAssertTrue(outcome.ticked)
        XCTAssertFalse(outcome.dayCompleted, "b is still outstanding — the day is not complete")
        XCTAssertTrue(store.completions.isEmpty)
        XCTAssertEqual(events.types, ["wird_ticked"])
    }

    func testArchivedWirdsDoNotBlockDayCompletion() {
        let store = InMemoryStore()
        store.wirds = [wird(id: "a", target: 3), wird(id: "old", target: 500, archived: true)]

        let outcome = makeResponder(store: store).answerCompleted(wirdId: "a")

        XCTAssertTrue(outcome.dayCompleted)
    }

    func testDayCompletionIsNotRecordedTwiceWhenAlreadyPresent() {
        let store = InMemoryStore()
        let events = SpyActivityEvents()
        store.wirds = [wird(id: "a", target: 3)]
        store.completions = [WirdDayCompletionRecord(dateKey: todayKey, completedAt: fixedNow)]

        let outcome = makeResponder(store: store, events: events).answerCompleted(wirdId: "a")

        XCTAssertTrue(outcome.ticked)
        XCTAssertFalse(outcome.dayCompleted)
        XCTAssertEqual(store.completions.count, 1)
        XCTAssertEqual(events.types, ["wird_ticked"])
    }

    // MARK: - Stale ids

    func testUnknownWirdIdIsANoOp() {
        let store = InMemoryStore()
        let events = SpyActivityEvents()
        store.wirds = [wird(id: "a", target: 3)]

        let outcome = makeResponder(store: store, events: events).answerCompleted(wirdId: "deleted")

        XCTAssertEqual(outcome, .unknownWird)
        XCTAssertTrue(store.progress.isEmpty)
        XCTAssertTrue(store.completions.isEmpty)
        XCTAssertTrue(events.recorded.isEmpty)
    }

    func testArchivedWirdIdIsANoOp() {
        let store = InMemoryStore()
        let events = SpyActivityEvents()
        store.wirds = [wird(id: "old", target: 3, archived: true)]

        let outcome = makeResponder(store: store, events: events).answerCompleted(wirdId: "old")

        XCTAssertEqual(outcome, .unknownWird)
        XCTAssertTrue(store.progress.isEmpty)
        XCTAssertTrue(events.recorded.isEmpty)
    }

    func testAnEmptyStoreIsANoOpRatherThanACrash() {
        let store = InMemoryStore()
        XCTAssertEqual(makeResponder(store: store).answerCompleted(wirdId: "anything"), .unknownWird)
    }

    // MARK: - Parity with the in-app path

    /// The whole point: whichever route the user takes, gamification sees the
    /// same events and the store lands in the same shape.
    @MainActor
    func testStoreAndEventsMatchTheInAppPath() {
        let notificationStore = InMemoryStore()
        let notificationEvents = SpyActivityEvents()
        notificationStore.wirds = [wird(id: "a", target: 7)]

        let uiStore = InMemoryStore()
        let uiEvents = SpyActivityEvents()
        uiStore.wirds = [wird(id: "a", target: 7)]

        makeResponder(store: notificationStore, events: notificationEvents).answerCompleted(wirdId: "a")

        let time = fixedNow
        let viewModel = AwradViewModel(
            store: uiStore, activityEvents: uiEvents, now: { time }, calendar: utcCalendar
        )
        viewModel.tick(wirdId: "a", amount: 7)
        viewModel.markDayComplete()

        XCTAssertEqual(notificationStore.progress, uiStore.progress)
        XCTAssertEqual(notificationStore.completions.map(\.dateKey), uiStore.completions.map(\.dateKey))
        XCTAssertEqual(notificationEvents.types, uiEvents.types)
        XCTAssertEqual(notificationEvents.recorded.first?.metadata, uiEvents.recorded.first?.metadata)
    }
}
