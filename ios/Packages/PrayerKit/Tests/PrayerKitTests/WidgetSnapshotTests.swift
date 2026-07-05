import XCTest
@testable import PrayerKit

final class WidgetSnapshotTests: XCTestCase {
    private let engine = PrayerEngine()

    private func timeline(days: Int) throws -> [PrayerDay] {
        try engine.timeline(
            latitude: 24.7136, longitude: 46.6753,
            startDate: DateComponents(year: 2026, month: 3, day: 20),
            days: days, settings: PrayerSettings(method: "umm_al_qura")
        )
    }

    func testBuildFiltersToHorizonAndSorts() throws {
        let days = try timeline(days: 5)
        let generatedAt = try XCTUnwrap(days.first).time(.fajr).addingTimeInterval(-3600)
        let hijri = HijriDate(from: generatedAt, offsetDays: 0)
        let snapshot = PrayerWidgetSnapshot.build(
            timeline: days, location: "الرياض", hijri: hijri,
            generatedAt: generatedAt, horizon: 48 * 3600
        )
        XCTAssertFalse(snapshot.upcoming.isEmpty)
        XCTAssertEqual(snapshot.upcoming, snapshot.upcoming.sorted { $0.time < $1.time })
        // ~5 prayers/day * 2 days = ~10 entries within 48h.
        XCTAssertLessThanOrEqual(snapshot.upcoming.count, 12)
        XCTAssertTrue(snapshot.upcoming.allSatisfy {
            $0.time <= generatedAt.addingTimeInterval(48 * 3600)
        })
        XCTAssertFalse(snapshot.upcoming.contains { $0.prayer == "sunrise" })
    }

    func testNextEntryAfterDate() throws {
        let days = try timeline(days: 2)
        // generatedAt just before the first prayer so the 48h horizon includes entries.
        let generatedAt = try XCTUnwrap(days.first).time(.fajr).addingTimeInterval(-3600)
        let snapshot = PrayerWidgetSnapshot.build(
            timeline: days, location: "x",
            hijri: HijriDate(from: generatedAt, offsetDays: 0), generatedAt: generatedAt
        )
        let first = try XCTUnwrap(snapshot.upcoming.first)
        let next = snapshot.nextEntry(after: first.time)
        XCTAssertNotNil(next)
        XCTAssertGreaterThan(try XCTUnwrap(next).time, first.time)
    }

    func testStoreRoundTrip() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        let store = WidgetSnapshotStore(appGroupContainer: dir)
        let days = try timeline(days: 2)
        // Whole-second date so ISO8601 encoding round-trips exactly.
        let generatedAt = try XCTUnwrap(days.first).time(.fajr).addingTimeInterval(-3600)
        let snapshot = PrayerWidgetSnapshot.build(
            timeline: days, location: "الرياض",
            hijri: HijriDate(from: generatedAt, offsetDays: 0), generatedAt: generatedAt
        )
        store.write(snapshot)
        XCTAssertEqual(store.read(), snapshot)
    }
}
