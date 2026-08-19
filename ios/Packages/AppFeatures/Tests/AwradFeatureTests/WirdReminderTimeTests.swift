import XCTest
@testable import AwradFeature

/// Per-wird reminder times (client request: "وقت محدد لكل ورد").
final class WirdReminderTimeTests: XCTestCase {

    func testAnOverrideWinsOverEverything() {
        let prefs = WirdReminderPreferences(hour: 20, minute: 0)
            .settingTime(WirdReminderTime(hour: 5, minute: 30), forWirdId: "fixed-morning-azkar")
        let time = prefs.time(forWirdId: "fixed-morning-azkar", slotDefaultHour: 8)
        // The user chose 05:30; the slot's built-in 08:00 must not override it.
        XCTAssertEqual(time, WirdReminderTime(hour: 5, minute: 30))
    }

    func testWithoutAnOverrideTheSlotDefaultIsUsed() {
        let prefs = WirdReminderPreferences(hour: 20, minute: 0)
        // أذكار الصباح still gets asked about in the morning rather than at the
        // generic evening time — the behaviour that existed before overrides.
        XCTAssertEqual(
            prefs.time(forWirdId: "fixed-morning-azkar", slotDefaultHour: 8),
            WirdReminderTime(hour: 8, minute: 0)
        )
    }

    func testAUserCreatedWirdFallsBackToTheGlobalTime() {
        let prefs = WirdReminderPreferences(hour: 21, minute: 15)
        XCTAssertEqual(
            prefs.time(forWirdId: "my-own-wird", slotDefaultHour: nil),
            WirdReminderTime(hour: 21, minute: 15)
        )
    }

    func testOverridesAreIndependentPerWird() {
        let prefs = WirdReminderPreferences()
            .settingTime(WirdReminderTime(hour: 3, minute: 0), forWirdId: "fixed-qiyam-al-layl")
            .settingTime(WirdReminderTime(hour: 6, minute: 45), forWirdId: "fixed-morning-azkar")
        XCTAssertEqual(
            prefs.time(forWirdId: "fixed-qiyam-al-layl", slotDefaultHour: 22).hour, 3
        )
        XCTAssertEqual(
            prefs.time(forWirdId: "fixed-morning-azkar", slotDefaultHour: 8).minute, 45
        )
        // An untouched wird is unaffected by the others' overrides.
        XCTAssertEqual(
            prefs.time(forWirdId: "fixed-evening-azkar", slotDefaultHour: 17).hour, 17
        )
    }

    func testOutOfRangeTimesAreClamped() {
        let time = WirdReminderTime(hour: 99, minute: -5)
        XCTAssertEqual(time.hour, 23)
        XCTAssertEqual(time.minute, 0)
    }

    // MARK: - Persistence

    func testAStoredBlobWrittenBeforePerWirdTimesStillLoads() throws {
        // Every installed device holds exactly this shape today.
        let legacy = Data(#"{"enabled":true,"hour":20,"minute":0}"#.utf8)
        let prefs = try JSONDecoder().decode(WirdReminderPreferences.self, from: legacy)
        XCTAssertTrue(prefs.enabled)
        XCTAssertEqual(prefs.hour, 20)
        XCTAssertTrue(prefs.timesByWird.isEmpty, "no overrides means unchanged behaviour")
    }

    func testOverridesRoundTrip() throws {
        let prefs = WirdReminderPreferences()
            .settingTime(WirdReminderTime(hour: 4, minute: 20), forWirdId: "fixed-qiyam-al-layl")
        let data = try JSONEncoder().encode(prefs)
        let decoded = try JSONDecoder().decode(WirdReminderPreferences.self, from: data)
        XCTAssertEqual(decoded, prefs)
    }

    func testACorruptOverrideBlobCostsTheOverrideNotTheReminders() throws {
        // The existing contract for this type: a bad field must never throw and
        // take the user's reminders down with it.
        let corrupt = Data(#"{"enabled":true,"hour":20,"minute":0,"timesByWird":"nonsense"}"#.utf8)
        let prefs = try JSONDecoder().decode(WirdReminderPreferences.self, from: corrupt)
        XCTAssertTrue(prefs.enabled)
        XCTAssertTrue(prefs.timesByWird.isEmpty)
    }
}
