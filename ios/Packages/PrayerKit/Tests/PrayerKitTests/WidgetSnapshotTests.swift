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

    // MARK: - Day sheets

    func testDaySheetKeepsSunriseThatUpcomingDrops() throws {
        let days = try timeline(days: 3)
        let generatedAt = try XCTUnwrap(days.first).time(.fajr).addingTimeInterval(-3600)
        let snapshot = PrayerWidgetSnapshot.build(
            timeline: days, location: "الرياض",
            hijri: HijriDate(from: generatedAt, offsetDays: 0), generatedAt: generatedAt
        )
        let sheet = try XCTUnwrap(snapshot.sheet(for: generatedAt))
        // The whole point of the second pass: sunrise is absent from `upcoming`
        // (asserted above) and present here.
        XCTAssertTrue(sheet.times.contains { $0.prayer == "sunrise" })
        XCTAssertEqual(sheet.times.count, PrayerName.allCases.count)
        XCTAssertEqual(sheet.times, sheet.times.sorted { $0.time < $1.time })
    }

    func testNightMarkersMatchTheNotificationPlannersLastThird() throws {
        let days = try timeline(days: 3)
        let generatedAt = try XCTUnwrap(days.first).time(.fajr).addingTimeInterval(-3600)
        let snapshot = PrayerWidgetSnapshot.build(
            timeline: days, location: "x",
            hijri: HijriDate(from: generatedAt, offsetDays: 0), generatedAt: generatedAt
        )
        let sheet = try XCTUnwrap(snapshot.sheet(for: generatedAt))
        let maghrib = try XCTUnwrap(days.first).time(.maghrib)
        let nextFajr = days[1].time(.fajr)
        let night = nextFajr.timeIntervalSince(maghrib)

        // Independently recomputed here rather than read back from NightTimes,
        // so this fails if the shared definition is ever changed underneath it.
        XCTAssertEqual(
            try XCTUnwrap(sheet.lastThird).timeIntervalSince(maghrib), night * 2 / 3, accuracy: 1
        )
        XCTAssertEqual(
            try XCTUnwrap(sheet.midnight).timeIntervalSince(maghrib), night / 2, accuracy: 1
        )
        // Midnight comes before the last third, always.
        XCTAssertLessThan(try XCTUnwrap(sheet.midnight), try XCTUnwrap(sheet.lastThird))
    }

    func testFinalDayHasNoNightMarkersRatherThanWrongOnes() throws {
        let days = try timeline(days: 2)
        let generatedAt = try XCTUnwrap(days.first).time(.fajr).addingTimeInterval(-3600)
        let snapshot = PrayerWidgetSnapshot.build(
            timeline: days, location: "x",
            hijri: HijriDate(from: generatedAt, offsetDays: 0), generatedAt: generatedAt
        )
        // The last day has no successor to take Fajr from. Absent beats invented.
        let last = try XCTUnwrap(snapshot.days.last)
        XCTAssertNil(last.midnight)
        XCTAssertNil(last.lastThird)
    }

    func testSheetKeepsThePreviousDayThroughTheSmallHours() throws {
        let days = try timeline(days: 3)
        let generatedAt = try XCTUnwrap(days.first).time(.fajr).addingTimeInterval(-3600)
        let snapshot = PrayerWidgetSnapshot.build(
            timeline: days, location: "x",
            hijri: HijriDate(from: generatedAt, offsetDays: 0), generatedAt: generatedAt
        )
        let firstSheet = try XCTUnwrap(snapshot.days.first)
        let lastThird = try XCTUnwrap(firstSheet.lastThird)
        // Standing *in* the last third — past clock midnight, before the next
        // Fajr. The sheet must still be the one whose night this is, or the
        // widget blanks the row the reader is awake for.
        let resolved = try XCTUnwrap(snapshot.sheet(for: lastThird.addingTimeInterval(60)))
        XCTAssertEqual(resolved.fajr, firstSheet.fajr)
    }

    func testDecodesSnapshotWrittenBeforeDaySheetsExisted() throws {
        // A v1 payload: no `days` key at all. The widget extension reads this
        // whenever the new build runs before the app has rewritten the snapshot.
        let json = """
        {"locationName":"الرياض","hijriMonthName":"صفر","hijriDay":25,"hijriYear":1448,
         "upcoming":[{"prayer":"fajr","time":"2026-08-08T02:36:00Z"}],
         "generatedAt":"2026-08-08T00:00:00Z"}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshot = try decoder.decode(
            PrayerWidgetSnapshot.self, from: Data(json.utf8)
        )
        // Decoding must succeed — the countdown widgets keep working...
        XCTAssertEqual(snapshot.upcoming.count, 1)
        XCTAssertEqual(snapshot.locationName, "الرياض")
        // ...and only the day sheet is unavailable.
        XCTAssertTrue(snapshot.days.isEmpty)
        XCTAssertNil(snapshot.sheet(for: Date()))
    }

    // MARK: - Timezone

    /// Regression test: widgets used to render every time via `Text(_,
    /// style: .time)`, which always uses the device's timezone — the same
    /// bug fixed for the main Prayer screen, on a different surface. The
    /// snapshot now carries the location's own timezone through `build(...)`.
    func testTimeZoneReflectsBuiltIdentifier() throws {
        let days = try timeline(days: 1)
        let generatedAt = try XCTUnwrap(days.first).time(.fajr)
        let snapshot = PrayerWidgetSnapshot.build(
            timeline: days, location: "الرياض",
            hijri: HijriDate(from: generatedAt, offsetDays: 0), generatedAt: generatedAt,
            timeZoneIdentifier: "Asia/Riyadh"
        )
        XCTAssertEqual(snapshot.timeZone.identifier, "Asia/Riyadh")
    }

    func testTimeZoneFallsBackToDeviceCurrentWhenNotKnown() throws {
        let days = try timeline(days: 1)
        let generatedAt = try XCTUnwrap(days.first).time(.fajr)
        let snapshot = PrayerWidgetSnapshot.build(
            timeline: days, location: "x",
            hijri: HijriDate(from: generatedAt, offsetDays: 0), generatedAt: generatedAt
        )
        XCTAssertEqual(snapshot.timeZone, .current)
    }

    /// Same reasoning as `testDecodesSnapshotWrittenBeforeDaySheetsExisted`:
    /// a snapshot written by an app build before this field existed has no
    /// `timeZoneIdentifier` key at all, and must still decode.
    func testDecodesSnapshotWrittenBeforeTimeZoneExisted() throws {
        let json = """
        {"locationName":"الرياض","hijriMonthName":"صفر","hijriDay":25,"hijriYear":1448,
         "upcoming":[{"prayer":"fajr","time":"2026-08-08T02:36:00Z"}],
         "generatedAt":"2026-08-08T00:00:00Z"}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshot = try decoder.decode(PrayerWidgetSnapshot.self, from: Data(json.utf8))
        XCTAssertNil(snapshot.timeZoneIdentifier)
        XCTAssertEqual(snapshot.timeZone, .current)
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
