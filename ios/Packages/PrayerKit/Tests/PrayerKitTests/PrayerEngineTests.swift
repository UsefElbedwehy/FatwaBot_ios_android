import XCTest
@testable import PrayerKit

final class PrayerEngineTests: XCTestCase {
    private let engine = PrayerEngine()
    private let riyadh = (lat: 24.7136, lng: 46.6753)
    private let march20 = DateComponents(year: 2026, month: 3, day: 20)

    private func day(_ settings: PrayerSettings = PrayerSettings(method: "umm_al_qura")) throws -> PrayerDay {
        try engine.day(
            latitude: riyadh.lat, longitude: riyadh.lng, date: march20, settings: settings
        )
    }

    func testAdjustmentsShiftOnlyTargetPrayer() throws {
        let base = try day()
        let adjusted = try day(PrayerSettings(method: "umm_al_qura", adjustments: [.fajr: 5, .isha: -10]))
        XCTAssertEqual(adjusted.time(.fajr).timeIntervalSince(base.time(.fajr)), 300)
        XCTAssertEqual(adjusted.time(.isha).timeIntervalSince(base.time(.isha)), -600)
        XCTAssertEqual(adjusted.time(.dhuhr), base.time(.dhuhr))
    }

    func testAdjustmentsAreClamped() {
        let settings = PrayerSettings(adjustments: [.fajr: 90, .asr: -90])
        XCTAssertEqual(settings.adjustments[.fajr], 30)
        XCTAssertEqual(settings.adjustments[.asr], -30)
    }

    func testNextPrayerMidDay() throws {
        let today = try day()
        // 1 minute after dhuhr → current dhuhr, next asr.
        let now = today.time(.dhuhr).addingTimeInterval(60)
        let state = PrayerEngine.nextPrayer(now: now, today: today, tomorrow: today)
        XCTAssertEqual(state.current, .dhuhr)
        XCTAssertEqual(state.next, .asr)
        XCTAssertEqual(state.nextTime, today.time(.asr))
    }

    func testNextPrayerSkipsSunrise() throws {
        let today = try day()
        // Between fajr and sunrise → next must be dhuhr-bound sequence, not sunrise.
        let now = today.time(.fajr).addingTimeInterval(60)
        let state = PrayerEngine.nextPrayer(now: now, today: today, tomorrow: today)
        XCTAssertEqual(state.current, .fajr)
        XCTAssertEqual(state.next, .dhuhr)
    }

    func testNextPrayerAfterIshaRollsToTomorrowFajr() throws {
        let today = try day()
        let tomorrow = try engine.day(
            latitude: riyadh.lat, longitude: riyadh.lng,
            date: DateComponents(year: 2026, month: 3, day: 21),
            settings: PrayerSettings(method: "umm_al_qura")
        )
        let now = today.time(.isha).addingTimeInterval(3600)
        let state = PrayerEngine.nextPrayer(now: now, today: today, tomorrow: tomorrow)
        XCTAssertEqual(state.current, .isha)
        XCTAssertEqual(state.next, .fajr)
        XCTAssertEqual(state.nextTime, tomorrow.time(.fajr))
        XCTAssertGreaterThan(state.nextTime, now)
    }

    func testBeforeFajrHasNoCurrentPrayer() throws {
        let today = try day()
        let now = today.time(.fajr).addingTimeInterval(-3600)
        let state = PrayerEngine.nextPrayer(now: now, today: today, tomorrow: today)
        XCTAssertNil(state.current)
        XCTAssertEqual(state.next, .fajr)
    }

    func testTimelineProducesConsecutiveDays() throws {
        let days = try engine.timeline(
            latitude: riyadh.lat, longitude: riyadh.lng,
            startDate: march20, days: 5,
            settings: PrayerSettings(method: "umm_al_qura")
        )
        XCTAssertEqual(days.count, 5)
        for pair in zip(days, days.dropFirst()) {
            let gap = pair.1.time(.fajr).timeIntervalSince(pair.0.time(.fajr))
            XCTAssert(abs(gap - 86_400) < 300, "fajr-to-fajr gap should be ~24h, got \(gap)")
        }
    }

    func testHighLatitudeAutoRuleAppliedAboveThreshold() {
        // Oslo with no explicit rule → engine must choose one (never library default).
        let rule = PrayerEngine.effectiveHighLatitudeRule(
            settings: PrayerSettings(method: "mwl"), latitude: 59.91
        )
        XCTAssertNotNil(rule)
        // Riyadh: no rule needed.
        XCTAssertNil(PrayerEngine.effectiveHighLatitudeRule(
            settings: PrayerSettings(method: "umm_al_qura"), latitude: 24.7
        ))
        // Explicit rule always wins.
        XCTAssertEqual(PrayerEngine.effectiveHighLatitudeRule(
            settings: PrayerSettings(method: "mwl", highLatitudeRule: "twilight_angle"), latitude: 10
        ), "twilight_angle")
    }

    func testHijriDateOffsetShiftsDay() {
        let date = Date(timeIntervalSince1970: 1_774_000_000) // 2026-03-20T…Z
        let base = HijriDate(from: date, offsetDays: 0)
        XCTAssertEqual(base.year, 1447)
        // Offset +1 must equal the Hijri date of the next civil day.
        let plusOne = HijriDate(from: date, offsetDays: 1)
        let nextDay = HijriDate(from: date.addingTimeInterval(86_400), offsetDays: 0)
        XCTAssertEqual(plusOne, nextDay)
        XCTAssertNotEqual(plusOne, base)
    }
}
