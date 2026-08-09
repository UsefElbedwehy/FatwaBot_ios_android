import XCTest
@testable import AwradFeature

/// أثرك shows the four fixed slots and nothing else (client decision,
/// 2026-08-09). The risk in that change is not what disappears from the screen
/// — it is what disappears from disk.
final class FixedOnlyBoardTests: XCTestCase {

    private final class InMemoryWirdStore: WirdStoring, @unchecked Sendable {
        var wirds: [Wird] = []
        func loadWirds() -> [Wird] { wirds }
        func saveWirds(_ wirds: [Wird]) { self.wirds = wirds }
        // Unused by these tests; the protocol is wider than the behaviour here.
        func loadProgress() -> [WirdDailyProgress] { [] }
        func saveProgress(_ progress: [WirdDailyProgress]) {}
        func loadDayCompletions() -> [WirdDayCompletionRecord] { [] }
        func recordDayCompletion(_ record: WirdDayCompletionRecord) {}
    }

    private func custom(_ id: String) -> Wird {
        Wird(
            id: id, name: "ورد مخصص", type: "custom", target: 3, unit: "times",
            frequency: "daily", createdAt: Date(timeIntervalSince1970: 0)
        )
    }

    private func makeStore(_ base: InMemoryWirdStore) -> SeededWirdStore {
        SeededWirdStore(
            wrapping: base,
            name: FixedWirdSlots.defaultNames,
            now: { Date(timeIntervalSince1970: 1_800_000_000) }
        )
    }

    func testTheBoardReturnsOnlyTheFourFixedSlots() {
        let base = InMemoryWirdStore()
        base.wirds = [custom("mine-1"), custom("mine-2")]
        let loaded = makeStore(base).loadWirds()

        XCTAssertEqual(loaded.count, FixedWirdSlot.allCases.count)
        XCTAssertTrue(loaded.allSatisfy(\.isFixed))
        XCTAssertFalse(loaded.contains { $0.id == "mine-1" })
    }

    func testSavingTheFilteredBoardDoesNotEraseUserWirdsFromDisk() {
        // The dangerous path: the view model loads (four slots), ticks a
        // counter, and saves what it has. A replacing write would drop the
        // user's own wirds permanently — hidden becoming destroyed on the first
        // tap, with nothing to undo it.
        let base = InMemoryWirdStore()
        base.wirds = [custom("mine-1")]
        let store = makeStore(base)

        let board = store.loadWirds()
        store.saveWirds(board)

        XCTAssertTrue(
            base.wirds.contains { $0.id == "mine-1" },
            "a user's own wird must survive a save of the filtered board"
        )
    }

    func testTheFourSlotsAreStillSeededOntoAnEmptyBoard() {
        let base = InMemoryWirdStore()
        XCTAssertEqual(makeStore(base).loadWirds().count, FixedWirdSlot.allCases.count)
    }
}
