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

    func testPlansAdhanForEnabledPrayersOnly() throws {
        let days = try timeline(days: 1, from: DateComponents(year: 2026, month: 3, day: 20))
        let now = Date(timeIntervalSince1970: 0) // long before, everything future
        let prefs = PrayerNotificationPreferences(adhanEnabled: [.fajr, .maghrib])
        let plan = NotificationPlanner.plan(timeline: days, preferences: prefs, now: now)
        XCTAssertEqual(Set(plan.map(\.prayer)), [.fajr, .maghrib])
        XCTAssertTrue(plan.allSatisfy { $0.kind == .adhan })
    }

    func testPreAdhanOffsetSchedulesEarlierReminder() throws {
        let days = try timeline(days: 1, from: DateComponents(year: 2026, month: 3, day: 20))
        let now = Date(timeIntervalSince1970: 0)
        let prefs = PrayerNotificationPreferences(
            adhanEnabled: [.dhuhr],
            preAdhanOffsetMinutes: [.dhuhr: 15]
        )
        let plan = NotificationPlanner.plan(timeline: days, preferences: prefs, now: now)
        let adhan = plan.first { $0.kind == .adhan && $0.prayer == .dhuhr }!
        let pre = plan.first { $0.kind == .preAdhan && $0.prayer == .dhuhr }!
        XCTAssertEqual(adhan.fireDate.timeIntervalSince(pre.fireDate), 900)
        // Ordered by fire date: pre-adhan precedes adhan.
        XCTAssertLessThan(
            plan.firstIndex(of: pre)!, plan.firstIndex(of: adhan)!
        )
    }

    func testPastFireDatesAreDropped() throws {
        let start = DateComponents(year: 2026, month: 3, day: 20)
        let days = try timeline(days: 1, from: start)
        // now = just after dhuhr; fajr/sunrise/dhuhr already passed.
        let now = days[0].time(.dhuhr).addingTimeInterval(60)
        let plan = NotificationPlanner.plan(
            timeline: days,
            preferences: PrayerNotificationPreferences(),
            now: now
        )
        XCTAssertFalse(plan.contains { $0.prayer == .fajr })
        XCTAssertTrue(plan.contains { $0.prayer == .asr })
        XCTAssertTrue(plan.allSatisfy { $0.fireDate > now })
    }

    func testBudgetCapKeepsEarliest() throws {
        let days = try timeline(days: 5, from: DateComponents(year: 2026, month: 3, day: 20))
        let now = Date(timeIntervalSince1970: 0)
        let plan = NotificationPlanner.plan(
            timeline: days,
            preferences: PrayerNotificationPreferences(),
            now: now,
            budget: 7
        )
        XCTAssertEqual(plan.count, 7)
        // Strictly increasing fire dates — the earliest 7 across 5 days.
        XCTAssertEqual(plan, plan.sorted { $0.fireDate < $1.fireDate })
    }

    func testIdsAreStableAndUnique() throws {
        let days = try timeline(days: 3, from: DateComponents(year: 2026, month: 3, day: 20))
        let now = Date(timeIntervalSince1970: 0)
        let plan = NotificationPlanner.plan(timeline: days, preferences: PrayerNotificationPreferences(), now: now)
        let ids = plan.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "ids must be unique for dedupe/reschedule")
        // Re-running yields identical ids (stable across reschedules).
        let again = NotificationPlanner.plan(timeline: days, preferences: PrayerNotificationPreferences(), now: now)
        XCTAssertEqual(plan, again)
    }
}
