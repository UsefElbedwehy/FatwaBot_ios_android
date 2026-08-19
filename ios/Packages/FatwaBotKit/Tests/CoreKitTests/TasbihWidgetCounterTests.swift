import XCTest
@testable import CoreKit

final class TasbihWidgetCounterTests: XCTestCase {
    private let calendar = Calendar.current

    func testIncrementRaisesTheTally() {
        var counter = TasbihWidgetCounter()
        counter = counter.incremented()
        counter = counter.incremented()
        XCTAssertEqual(counter.current(), 2)
    }

    func testATallyFromAnEarlierDayReadsAsZero() {
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        let stale = TasbihWidgetCounter(count: 100, day: calendar.startOfDay(for: yesterday))
        // Without this, someone who counted 100 last night opens their phone to
        // a widget claiming 100 today.
        XCTAssertEqual(stale.current(on: Date()), 0)
    }

    func testIncrementingAStaleTallyStartsFromZeroNotFromYesterday() {
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        let stale = TasbihWidgetCounter(count: 100, day: calendar.startOfDay(for: yesterday))
        let today = stale.incremented(on: Date())
        // The first tap of a new day must read 1, not 101.
        XCTAssertEqual(today.current(), 1)
    }

    func testResetZeroesAndClaimsToday() {
        let counter = TasbihWidgetCounter(count: 33).reset()
        XCTAssertEqual(counter.current(), 0)
        XCTAssertTrue(calendar.isDateInToday(counter.day))
    }

    func testStoreRoundTrips() {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = TasbihWidgetCounterStore(appGroupContainer: dir)
        store.write(TasbihWidgetCounter().incremented().incremented().incremented())
        XCTAssertEqual(store.read().current(), 3)
    }

    func testReadingBeforeAnythingWasWrittenIsZeroNotAFailure() {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        // Every install takes this path once; it must not throw or show a
        // placeholder where a number belongs.
        XCTAssertEqual(TasbihWidgetCounterStore(appGroupContainer: dir).read().current(), 0)
    }
}
