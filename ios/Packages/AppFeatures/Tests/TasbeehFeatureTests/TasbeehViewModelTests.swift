import XCTest
import CoreKit
@testable import TasbeehFeature

final class TasbeehViewModelTests: XCTestCase {
    final class SpyHaptics: HapticsProviding, @unchecked Sendable {
        var tickCount = 0
        var targetReachedCount = 0
        func tick() { tickCount += 1 }
        func targetReached() { targetReachedCount += 1 }
    }

    final class InMemoryStore: TasbeehHistoryStoring, @unchecked Sendable {
        var entries: [TasbeehHistoryEntry] = []
        func load() -> [TasbeehHistoryEntry] { entries }
        func save(_ history: [TasbeehHistoryEntry]) { entries = history }
    }

    final class SpyActivityEvents: ActivityEventRecording, @unchecked Sendable {
        var recorded: [(eventType: String, metadata: [String: String])] = []
        func record(eventType: String, metadata: [String: String]) { recorded.append((eventType, metadata)) }
    }

    @MainActor
    func testIncrementPastTargetDoesNotResetOrBlock() {
        let viewModel = TasbeehViewModel(store: InMemoryStore())
        viewModel.changeTarget(3)
        for _ in 0..<10 { viewModel.increment() }
        XCTAssertEqual(viewModel.count, 10, "counting past target must not reset or stop")
    }

    @MainActor
    func testDistinctHapticFiresExactlyOnceAtTargetCrossing() {
        let haptics = SpyHaptics()
        let viewModel = TasbeehViewModel(haptics: haptics, store: InMemoryStore())
        viewModel.changeTarget(3)
        for _ in 0..<5 { viewModel.increment() }
        XCTAssertEqual(haptics.targetReachedCount, 1, "target-reached haptic must fire exactly once")
        XCTAssertEqual(haptics.tickCount, 4, "every other tick uses the regular haptic")
    }

    @MainActor
    func testResetZeroesCountWithoutTouchingHistory() {
        let viewModel = TasbeehViewModel(store: InMemoryStore())
        viewModel.changeTarget(3)
        viewModel.increment()
        viewModel.increment()
        viewModel.reset()
        XCTAssertEqual(viewModel.count, 0)
        XCTAssertTrue(viewModel.history.isEmpty)
    }

    @MainActor
    func testHistoryTotalIsSumOfActualCountsNotTargets() {
        let store = InMemoryStore()
        let viewModel = TasbeehViewModel(store: store)
        viewModel.changeTarget(3)
        for _ in 0..<5 { viewModel.increment() } // overshoots target
        viewModel.completeSet()
        viewModel.changeTarget(3)
        for _ in 0..<3 { viewModel.increment() } // exact
        viewModel.completeSet()

        XCTAssertEqual(viewModel.stats.setsCompleted, 2)
        XCTAssertEqual(viewModel.stats.totalCount, 8, "5 + 3 actual, not 3 + 3 target")
        XCTAssertEqual(store.entries.count, 2, "completion persists to the store")
    }

    @MainActor
    func testCompleteSetWithZeroCountIsANoOp() {
        let store = InMemoryStore()
        let viewModel = TasbeehViewModel(store: store)
        viewModel.completeSet()
        XCTAssertTrue(store.entries.isEmpty, "completing an empty set should not record history")
    }

    @MainActor
    func testCustomDhikrTextIsNotSavedAsAPreset() {
        let viewModel = TasbeehViewModel(store: InMemoryStore())
        viewModel.select(preset: .custom)
        viewModel.customText = "دعاء خاص"
        XCTAssertEqual(viewModel.displayText, "دعاء خاص")
        // Presets list is a static bundled constant, unaffected by custom text.
        XCTAssertEqual(DhikrPreset.bundled.map(\.id).contains("دعاء خاص"), false)
        XCTAssertFalse(DhikrPreset.bundled.contains(where: { $0.arabicText == "دعاء خاص" }))
    }

    @MainActor
    func testSelectingPresetResetsInProgressCount() {
        let viewModel = TasbeehViewModel(store: InMemoryStore())
        viewModel.increment()
        viewModel.increment()
        viewModel.select(preset: DhikrPreset.bundled[1])
        XCTAssertEqual(viewModel.count, 0, "switching dhikr should not carry over an in-progress count")
    }

    @MainActor
    func testCompleteSetRecordsAnActivityEvent() {
        let events = SpyActivityEvents()
        let viewModel = TasbeehViewModel(store: InMemoryStore(), activityEvents: events)
        viewModel.increment()
        viewModel.completeSet()
        XCTAssertEqual(events.recorded.map(\.eventType), ["tasbeeh_session_completed"])
    }

    @MainActor
    func testCompleteSetWithZeroCountDoesNotRecordAnActivityEvent() {
        let events = SpyActivityEvents()
        let viewModel = TasbeehViewModel(store: InMemoryStore(), activityEvents: events)
        viewModel.completeSet()
        XCTAssertTrue(events.recorded.isEmpty)
    }

    @MainActor
    func testHistoryLoadsFromStoreOnInit() {
        let store = InMemoryStore()
        store.entries = [
            TasbeehHistoryEntry(presetId: "subhanallah", customText: nil, target: 33, actualCount: 33, completedAt: Date()),
        ]
        let viewModel = TasbeehViewModel(store: store)
        XCTAssertEqual(viewModel.history.count, 1)
        XCTAssertEqual(viewModel.stats.totalCount, 33)
    }
}
