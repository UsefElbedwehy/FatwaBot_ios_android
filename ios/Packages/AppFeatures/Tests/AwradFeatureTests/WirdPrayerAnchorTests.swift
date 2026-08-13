import XCTest
@testable import AwradFeature

/// Anchoring a wird's reminder to a prayer instead of a clock time
/// (client request: "خيار وقت الفجر لأذكار الصباح").
final class WirdPrayerAnchorTests: XCTestCase {
    private let morningId = "fixed-morning-azkar"

    private func wird(_ id: String, name: String = "أذكار الصباح") -> Wird {
        Wird(
            id: id, name: name, type: "azkar", target: 1, unit: "times",
            frequency: "daily", createdAt: Date(timeIntervalSince1970: 0), isFixed: true
        )
    }

    /// Fajr at 04:36 local on each of the next few days.
    private func fajrLookup(from base: Date) -> WirdReminderPlanner.PrayerTimeLookup {
        { offset, prayer in
            guard prayer == "fajr" else { return nil }
            return base.addingTimeInterval(TimeInterval(offset) * 86_400)
        }
    }

    func testAnchoredWirdFiresRelativeToThePrayerNotTheClock() {
        let fajr = Date(timeIntervalSince1970: 1_800_000_000)
        let prefs = WirdReminderPreferences(hour: 20, minute: 0)
            .settingPrayerAnchor(prayer: "fajr", offsetMinutes: 30, forWirdId: morningId)
        let plan = WirdReminderPlanner.plan(
            wirds: [wird(morningId)], preferences: prefs, budget: 5,
            now: fajr.addingTimeInterval(-3600), prayerTime: fajrLookup(from: fajr)
        )
        XCTAssertFalse(plan.isEmpty)
        guard case let .oneShot(date) = plan[0].trigger else {
            return XCTFail("an anchored wird must produce dated reminders, not a daily repeat")
        }
        // 30 minutes after Fajr, not the 20:00 clock time sitting in preferences.
        XCTAssertEqual(date, fajr.addingTimeInterval(1800))
    }

    func testAnchoredWirdEmitsOneReminderPerDayOfHorizon() {
        let fajr = Date(timeIntervalSince1970: 1_800_000_000)
        let prefs = WirdReminderPreferences()
            .settingPrayerAnchor(prayer: "fajr", offsetMinutes: 0, forWirdId: morningId)
        let plan = WirdReminderPlanner.plan(
            wirds: [wird(morningId)], preferences: prefs, budget: 5,
            now: fajr.addingTimeInterval(-60), prayerTime: fajrLookup(from: fajr)
        )
        // A moving target cannot be a repeating trigger, so it costs a slot a day.
        XCTAssertEqual(plan.count, WirdReminderPlanner.prayerAnchorHorizonDays)
        XCTAssertTrue(plan.allSatisfy {
            if case .oneShot = $0.trigger { return true } else { return false }
        })
    }

    func testAPrayerAlreadyPastTodayIsSkipped() {
        let fajr = Date(timeIntervalSince1970: 1_800_000_000)
        let prefs = WirdReminderPreferences()
            .settingPrayerAnchor(prayer: "fajr", offsetMinutes: 0, forWirdId: morningId)
        // Opened the app after Fajr — today's is gone, tomorrow's is not.
        let plan = WirdReminderPlanner.plan(
            wirds: [wird(morningId)], preferences: prefs, budget: 5,
            now: fajr.addingTimeInterval(3600), prayerTime: fajrLookup(from: fajr)
        )
        XCTAssertEqual(plan.count, WirdReminderPlanner.prayerAnchorHorizonDays - 1)
    }

    func testWithoutPrayerTimesAnAnchoredWirdFallsBackToItsClockTime() {
        let prefs = WirdReminderPreferences(hour: 21, minute: 15)
            .settingPrayerAnchor(prayer: "fajr", offsetMinutes: 0, forWirdId: morningId)
        // No location yet, so no timeline. A reminder at a slightly wrong hour
        // beats a wird that silently stops asking.
        let plan = WirdReminderPlanner.plan(
            wirds: [wird(morningId)], preferences: prefs, budget: 5, prayerTime: nil
        )
        XCTAssertEqual(plan.count, 1)
        XCTAssertEqual(plan[0].trigger, .dailyAt(hour: 8, minute: 0))
    }

    func testClearingTheAnchorRestoresTheChosenClockTime() {
        let prefs = WirdReminderPreferences()
            .settingTime(WirdReminderTime(hour: 6, minute: 30), forWirdId: morningId)
            .settingPrayerAnchor(prayer: "fajr", offsetMinutes: 0, forWirdId: morningId)
            .clearingPrayerAnchor(forWirdId: morningId)
        // Switching to Fajr and back must return the user's own time, not reset it.
        XCTAssertNil(prefs.prayerAnchor(forWirdId: morningId))
        XCTAssertEqual(
            prefs.time(forWirdId: morningId, slotDefaultHour: 8),
            WirdReminderTime(hour: 6, minute: 30)
        )
    }

    func testTheBudgetCountsRemindersNotWirds() {
        let fajr = Date(timeIntervalSince1970: 1_800_000_000)
        let prefs = WirdReminderPreferences()
            .settingPrayerAnchor(prayer: "fajr", offsetMinutes: 0, forWirdId: morningId)
        let plan = WirdReminderPlanner.plan(
            wirds: [wird(morningId)], preferences: prefs, budget: 2,
            now: fajr.addingTimeInterval(-60), prayerTime: fajrLookup(from: fajr)
        )
        // Counting wirds would have let one anchored wird emit three requests
        // against a budget of two and overshoot the reserve.
        XCTAssertEqual(plan.count, 2)
    }

    /// Client report: قيام الليل's reminder went silent with nothing to
    /// explain why. Root cause — anchoring *both* azkar slots to a prayer
    /// costs `prayerAnchorHorizonDays` (3) reminders each, 6 total, which used
    /// to exceed the old reserve of 5 outright; قيام الليل sorts last among
    /// the fixed slots and lost the budget race silently. Uses the *default*
    /// reserve (no explicit `budget:` override), unlike the tests above, so
    /// this fails again if the reserve ever regresses back down.
    func testAllFourFixedSlotsFitTheDefaultReserveEvenWithBothAzkarAnchored() {
        let eveningId = "fixed-evening-azkar"
        let qiyamId = "fixed-qiyam-al-layl"
        let quranId = "fixed-daily-quran"
        let fajr = Date(timeIntervalSince1970: 1_800_000_000)
        let prefs = WirdReminderPreferences()
            .settingPrayerAnchor(prayer: "fajr", offsetMinutes: 0, forWirdId: morningId)
            .settingPrayerAnchor(prayer: "asr", offsetMinutes: 0, forWirdId: eveningId)
        let lookup: WirdReminderPlanner.PrayerTimeLookup = { offset, prayer in
            switch prayer {
            case "fajr": return fajr.addingTimeInterval(TimeInterval(offset) * 86_400)
            case "asr": return fajr.addingTimeInterval(TimeInterval(offset) * 86_400 + 36_000)
            default: return nil
            }
        }
        let wirds = [
            wird(morningId), wird(eveningId, name: "أذكار المساء"),
            wird(qiyamId, name: "قيام الليل"), wird(quranId, name: "ورد يومي من القرآن"),
        ]

        let plan = WirdReminderPlanner.plan(
            wirds: wirds, preferences: prefs, now: fajr.addingTimeInterval(-60), prayerTime: lookup
        )

        for id in [morningId, eveningId, qiyamId, quranId] {
            XCTAssertTrue(plan.contains { $0.wirdId == id }, "\(id) must get at least one reminder")
        }
    }

    func testAnchorsSurviveAStoredRoundTrip() throws {
        let prefs = WirdReminderPreferences()
            .settingPrayerAnchor(prayer: "fajr", offsetMinutes: 15, forWirdId: morningId)
        let data = try JSONEncoder().encode(prefs)
        let decoded = try JSONDecoder().decode(WirdReminderPreferences.self, from: data)
        XCTAssertEqual(decoded.prayerAnchor(forWirdId: morningId)?.prayer, "fajr")
        XCTAssertEqual(decoded.prayerAnchor(forWirdId: morningId)?.offsetMinutes, 15)
    }

    func testABlobWithoutAnchorsStillLoads() throws {
        let legacy = Data(#"{"enabled":true,"hour":20,"minute":0}"#.utf8)
        let prefs = try JSONDecoder().decode(WirdReminderPreferences.self, from: legacy)
        XCTAssertTrue(prefs.prayerAnchorsByWird.isEmpty)
    }
}
