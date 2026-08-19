import XCTest
@testable import PrayerKit

/// How the schedule is cut down when it does not fit the platform's pending-
/// notification budget. Split from NotificationPlannerTests because these are
/// about allocation policy, not about which reminders get built.
final class NotificationBudgetTests: XCTestCase {
    private let engine = PrayerEngine()

    private func timeline(days: Int, from date: DateComponents) throws -> [PrayerDay] {
        try engine.timeline(
            latitude: 24.7136, longitude: 46.6753,
            startDate: date, days: days,
            settings: PrayerSettings(method: "umm_al_qura")
        )
    }

    // MARK: - Budget allocation

    /// Everything on: 5 adhan + 5 pre-adhan + 5 iqama + 1 last third per day.
    private func fullPreferences() -> PrayerNotificationPreferences {
        PrayerNotificationPreferences(
            adhanEnabled: true, preAdhanEnabled: true, preAdhanOffsetMinutes: 10,
            iqamaEnabled: true, lastThirdEnabled: true
        )
    }

    func testAdhanSurvivesAcrossTheWholeHorizonWhenTheBudgetIsTight() throws {
        let days = try timeline(days: 10, from: DateComponents(year: 2026, month: 3, day: 20))
        let now = days[0].time(PrayerName.fajr).addingTimeInterval(-3600)
        let plan = NotificationPlanner.plan(
            timeline: days, preferences: fullPreferences(), now: now, budget: 48
        )

        // The bug: chronological truncation gave three days of everything and
        // then silence — no adhan at all from day four. Priority allocation must
        // reach much further with the same 48 slots.
        let adhanDays = Set(
            plan.filter { $0.kind == PlannedNotification.Kind.adhan }.map {
                Calendar.current.startOfDay(for: $0.fireDate)
            }
        )
        // Measured under the tiered policy: two days of every reminder type,
        // then the rest of the budget on adhan. Six days, against the three the
        // old chronological truncation gave — and unlike pure adhan-first
        // allocation, the pre-adhan nudge survives (see the test below).
        XCTAssertGreaterThanOrEqual(adhanDays.count, 6, "adhan must reach well past day three")
        XCTAssertLessThanOrEqual(plan.count, 48)
    }

    func testSoftRemindersSurviveNearTerm() throws {
        let days = try timeline(days: 10, from: DateComponents(year: 2026, month: 3, day: 20))
        let now = days[0].time(PrayerName.fajr).addingTimeInterval(-3600)
        let plan = NotificationPlanner.plan(
            timeline: days, preferences: fullPreferences(), now: now, budget: 48
        )
        // Pure adhan-first allocation would buy a longer horizon but strip the
        // pre-adhan nudge entirely — a regression the user notices the next day.
        let cutoff = now.addingTimeInterval(
            TimeInterval(NotificationPlanner.fullFidelityDays) * 86_400
        )
        let nearSoft = plan.filter {
            $0.fireDate < cutoff && $0.kind != PlannedNotification.Kind.adhan
        }
        XCTAssertFalse(nearSoft.isEmpty, "near-term must keep every enabled type")
    }

    func testBeyondTheFullFidelityWindowOnlyTheAdhanSurvives() throws {
        let days = try timeline(days: 10, from: DateComponents(year: 2026, month: 3, day: 20))
        let now = days[0].time(PrayerName.fajr).addingTimeInterval(-3600)
        let plan = NotificationPlanner.plan(
            timeline: days, preferences: fullPreferences(), now: now, budget: 48
        )
        let cutoff = now.addingTimeInterval(
            TimeInterval(NotificationPlanner.fullFidelityDays) * 86_400
        )
        // The trade that buys the horizon: past the window the budget goes to
        // the one reminder a user cannot substitute for themselves.
        XCTAssertTrue(
            plan.filter { $0.fireDate >= cutoff }
                .allSatisfy { $0.kind == PlannedNotification.Kind.adhan }
        )
    }

    func testThePlanIsStillChronologicalAfterAllocation() throws {
        let days = try timeline(days: 10, from: DateComponents(year: 2026, month: 3, day: 20))
        let now = days[0].time(PrayerName.fajr).addingTimeInterval(-3600)
        let plan = NotificationPlanner.plan(
            timeline: days, preferences: fullPreferences(), now: now, budget: 48
        )
        // Allocation reorders internally; the caller registers these in order and
        // a scrambled list would be registered out of sequence.
        XCTAssertEqual(plan.map(\.fireDate), plan.map(\.fireDate).sorted())
    }

    func testAPlanThatFitsIsLeftCompletelyAlone() throws {
        let days = try timeline(days: 2, from: DateComponents(year: 2026, month: 3, day: 20))
        let now = days[0].time(PrayerName.fajr).addingTimeInterval(-3600)
        let plan = NotificationPlanner.plan(
            timeline: days, preferences: fullPreferences(), now: now, budget: 10_000
        )
        // Under budget, every reminder the user asked for must be present —
        // prioritisation must not quietly drop things when there is room.
        XCTAssertTrue(plan.contains { $0.kind == PlannedNotification.Kind.iqama })
        XCTAssertTrue(plan.contains { $0.kind == PlannedNotification.Kind.lastThird })
        XCTAssertTrue(plan.contains { $0.kind == PlannedNotification.Kind.preAdhan })
    }
}
