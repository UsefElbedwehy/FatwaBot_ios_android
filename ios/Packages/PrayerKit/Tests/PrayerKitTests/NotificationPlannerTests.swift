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
            adhanEnabled: false, preAdhanEnabled: false, iqamaEnabled: true, iqamaOffsetMinutes: 20
        )
        let plan = NotificationPlanner.plan(timeline: days, preferences: prefs, now: now)
        XCTAssertTrue(plan.allSatisfy { $0.kind == .iqama })
        let asr = plan.first { $0.prayer == .asr }!
        XCTAssertEqual(asr.fireDate.timeIntervalSince(days[0].time(.asr)), 1200)
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
