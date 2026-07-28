import XCTest
@testable import PrayerKit

final class NotificationPlannerTests: XCTestCase {
    private let engine = PrayerEngine()

    private func timeline(days: Int, from date: DateComponents) throws -> [PrayerDay] {
        try engine.timeline(
            latitude: 24.7136, longitude: 46.6753,
            startDate: date, days: days,
            settings: PrayerSettings(method: "umm_al_qura")
        )
    }

    func testAdhanOnlyWhenOtherTypesDisabled() throws {
        let days = try timeline(days: 1, from: DateComponents(year: 2026, month: 3, day: 20))
        let now = Date(timeIntervalSince1970: 0) // long before, everything future
        let prefs = PrayerNotificationPreferences(adhanEnabled: true, preAdhanEnabled: false)
        let plan = NotificationPlanner.plan(timeline: days, preferences: prefs, now: now)
        XCTAssertTrue(plan.allSatisfy { $0.kind == .adhan })
        XCTAssertEqual(Set(plan.compactMap(\.prayer)), Set(PrayerName.allCases.filter(\.isPrayer)))
    }

    func testAdhanDisabledEmitsNothingForThatType() throws {
        let days = try timeline(days: 1, from: DateComponents(year: 2026, month: 3, day: 20))
        let now = Date(timeIntervalSince1970: 0)
        let prefs = PrayerNotificationPreferences(adhanEnabled: false, preAdhanEnabled: false)
        let plan = NotificationPlanner.plan(timeline: days, preferences: prefs, now: now)
        XCTAssertTrue(plan.isEmpty)
    }

    func testPreAdhanOffsetSchedulesEarlierReminder() throws {
        let days = try timeline(days: 1, from: DateComponents(year: 2026, month: 3, day: 20))
        let now = Date(timeIntervalSince1970: 0)
        let prefs = PrayerNotificationPreferences(
            adhanEnabled: true, preAdhanEnabled: true, preAdhanOffsetMinutes: 15
        )
        let plan = NotificationPlanner.plan(timeline: days, preferences: prefs, now: now)
        let adhan = plan.first { $0.kind == .adhan && $0.prayer == .dhuhr }!
        let pre = plan.first { $0.kind == .preAdhan && $0.prayer == .dhuhr }!
        XCTAssertEqual(adhan.fireDate.timeIntervalSince(pre.fireDate), 900)
        XCTAssertLessThan(plan.firstIndex(of: pre)!, plan.firstIndex(of: adhan)!)
    }

    func testIqamaReminderFiresAfterAdhan() throws {
        let days = try timeline(days: 1, from: DateComponents(year: 2026, month: 3, day: 20))
        let now = Date(timeIntervalSince1970: 0)
        let prefs = PrayerNotificationPreferences(
            adhanEnabled: false, preAdhanEnabled: false, iqamaEnabled: true
        )
        let plan = NotificationPlanner.plan(timeline: days, preferences: prefs, now: now)
        XCTAssertTrue(plan.allSatisfy { $0.kind == .iqama })

        // The gap is per prayer now: Fajr waits longer than the rest, matching
        // mosque practice. A single shared offset would put Fajr at 10 too.
        let fajr = plan.first { $0.prayer == .fajr }!
        XCTAssertEqual(fajr.fireDate.timeIntervalSince(days[0].time(.fajr)), 20 * 60)
        let asr = plan.first { $0.prayer == .asr }!
        XCTAssertEqual(asr.fireDate.timeIntervalSince(days[0].time(.asr)), 10 * 60)

        // Sunrise is not a prayer and never gets a congregation reminder.
        XCTAssertNil(plan.first { $0.prayer == .sunrise })
    }

    func testLastThirdFiresTwoThirdsIntoTheNight() throws {
        let days = try timeline(days: 2, from: DateComponents(year: 2026, month: 3, day: 20))
        let now = Date(timeIntervalSince1970: 0)
        let prefs = PrayerNotificationPreferences(
            adhanEnabled: false, preAdhanEnabled: false, lastThirdEnabled: true
        )
        let plan = NotificationPlanner.plan(timeline: days, preferences: prefs, now: now)
        // One night has a following-day Fajr (day 0 → day 1); the last day cannot.
        XCTAssertEqual(plan.count, 1)
        let n = plan[0]
        XCTAssertEqual(n.kind, .lastThird)
        XCTAssertNil(n.prayer)
        let maghrib = days[0].time(.maghrib)
        let fajrNext = days[1].time(.fajr)
        let expected = maghrib.addingTimeInterval(fajrNext.timeIntervalSince(maghrib) * 2.0 / 3.0)
        XCTAssertEqual(n.fireDate.timeIntervalSince1970, expected.timeIntervalSince1970, accuracy: 1)
        XCTAssertGreaterThan(n.fireDate, maghrib)
        XCTAssertLessThan(n.fireDate, fajrNext)
    }

    func testPastFireDatesAreDropped() throws {
        let start = DateComponents(year: 2026, month: 3, day: 20)
        let days = try timeline(days: 1, from: start)
        let now = days[0].time(.dhuhr).addingTimeInterval(60)
        let plan = NotificationPlanner.plan(
            timeline: days, preferences: PrayerNotificationPreferences(), now: now
        )
        XCTAssertFalse(plan.contains { $0.prayer == .fajr })
        XCTAssertTrue(plan.contains { $0.prayer == .asr })
        XCTAssertTrue(plan.allSatisfy { $0.fireDate > now })
    }

    func testBudgetCapKeepsEarliest() throws {
        let days = try timeline(days: 5, from: DateComponents(year: 2026, month: 3, day: 20))
        let now = Date(timeIntervalSince1970: 0)
        let plan = NotificationPlanner.plan(
            timeline: days, preferences: PrayerNotificationPreferences(), now: now, budget: 7
        )
        XCTAssertEqual(plan.count, 7)
        XCTAssertEqual(plan, plan.sorted { $0.fireDate < $1.fireDate })
    }

    func testIdsAreStableAndUnique() throws {
        let days = try timeline(days: 3, from: DateComponents(year: 2026, month: 3, day: 20))
        let now = Date(timeIntervalSince1970: 0)
        let prefs = PrayerNotificationPreferences(
            adhanEnabled: true, preAdhanEnabled: true, iqamaEnabled: true, lastThirdEnabled: true
        )
        let plan = NotificationPlanner.plan(timeline: days, preferences: prefs, now: now)
        let ids = plan.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "ids must be unique for dedupe/reschedule")
        let again = NotificationPlanner.plan(timeline: days, preferences: prefs, now: now)
        XCTAssertEqual(plan, again)
    }
}

/// The iqama gap became per-prayer. These cover the decode path, because getting
/// it wrong silently resets a user's notification settings on upgrade — a failure
/// nobody would report as a bug, they'd just quietly lose their configuration.
final class IqamaOffsetMigrationTests: XCTestCase {
    private func decode(_ json: String) throws -> PrayerNotificationPreferences {
        try JSONDecoder().decode(PrayerNotificationPreferences.self, from: Data(json.utf8))
    }

    func testDefaultsFollowMosqueConvention() {
        let prefs = PrayerNotificationPreferences()
        XCTAssertEqual(prefs.iqamaOffset(for: .fajr), 20)
        for prayer in [PrayerName.dhuhr, .asr, .maghrib, .isha] {
            XCTAssertEqual(prefs.iqamaOffset(for: prayer), 10, "\(prayer) should default to 10")
        }
    }

    /// Stored JSON on an already-installed device.
    func testLegacyScalarIsCarriedOntoEveryPrayer() throws {
        let prefs = try decode(#"{"adhanEnabled":true,"preAdhanEnabled":true,"preAdhanOffsetMinutes":10,"iqamaEnabled":true,"iqamaOffsetMinutes":15,"lastThirdEnabled":false}"#)
        XCTAssertTrue(prefs.iqamaEnabled, "the user's on/off choice must survive")
        for prayer in [PrayerName.fajr, .dhuhr, .asr, .maghrib, .isha] {
            XCTAssertEqual(prefs.iqamaOffset(for: prayer), 15, "legacy 15 should carry to \(prayer)")
        }
    }

    func testNewShapeRoundTrips() throws {
        var prefs = PrayerNotificationPreferences(iqamaEnabled: true)
        prefs.iqamaOffsetsByPrayer[PrayerName.asr.rawValue] = 25
        let restored = try decode(String(data: JSONEncoder().encode(prefs), encoding: .utf8)!)
        XCTAssertEqual(restored.iqamaOffset(for: .asr), 25)
        XCTAssertEqual(restored.iqamaOffset(for: .fajr), 20)
    }

    /// A pack written by a newer build, or a hand-edited file, must not drop the
    /// prayers it omits.
    func testPartialDictionaryFallsBackPerPrayer() throws {
        let prefs = try decode(#"{"iqamaEnabled":true,"iqamaOffsetsByPrayer":{"fajr":25}}"#)
        XCTAssertEqual(prefs.iqamaOffset(for: .fajr), 25)
        XCTAssertEqual(prefs.iqamaOffset(for: .isha), 10, "missing key falls back to the default")
    }

    func testOffsetsAreClampedOnDecode() throws {
        let prefs = try decode(#"{"iqamaOffsetsByPrayer":{"fajr":9999,"asr":0}}"#)
        XCTAssertEqual(prefs.iqamaOffset(for: .fajr), 60)
        XCTAssertEqual(prefs.iqamaOffset(for: .asr), 1)
    }

    /// The legacy key is read once for migration and never written back.
    func testEncodedOutputDropsTheLegacyKey() throws {
        let data = try JSONEncoder().encode(PrayerNotificationPreferences(iqamaEnabled: true))
        let json = String(data: data, encoding: .utf8)!
        XCTAssertFalse(json.contains("iqamaOffsetMinutes"), "legacy key should not be re-emitted")
        XCTAssertTrue(json.contains("iqamaOffsetsByPrayer"))
    }
}
