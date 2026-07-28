import XCTest
@testable import AwradFeature

final class WirdReminderPlannerTests: XCTestCase {
    private func wird(id: String, name: String = "ورد", archived: Bool = false, createdOffset: TimeInterval = 0) -> Wird {
        Wird(
            id: id, name: name, type: "dhikr", target: 33, unit: "times", frequency: "daily",
            createdAt: Date(timeIntervalSince1970: 1_770_000_000 + createdOffset),
            archivedAt: archived ? Date(timeIntervalSince1970: 1_773_000_000) : nil
        )
    }

    func testOneReminderPerActiveWird() {
        let plan = WirdReminderPlanner.plan(
            wirds: [wird(id: "a", createdOffset: 0), wird(id: "b", createdOffset: 10)],
            preferences: WirdReminderPreferences()
        )
        XCTAssertEqual(plan.map(\.wirdId), ["a", "b"])
        XCTAssertEqual(plan.map(\.id), ["wird-reminder-a", "wird-reminder-b"])
        XCTAssertEqual(Set(plan.map(\.hour)), [20])
        XCTAssertEqual(Set(plan.map(\.minute)), [0])
    }

    func testArchivedWirdsGetNoReminder() {
        let plan = WirdReminderPlanner.plan(
            wirds: [wird(id: "a"), wird(id: "old", archived: true, createdOffset: 5)],
            preferences: WirdReminderPreferences()
        )
        XCTAssertEqual(plan.map(\.wirdId), ["a"])
    }

    func testNoAwradYieldsNoReminders() {
        XCTAssertTrue(WirdReminderPlanner.plan(wirds: [], preferences: WirdReminderPreferences()).isEmpty)
    }

    func testOnlyArchivedAwradYieldsNoReminders() {
        let plan = WirdReminderPlanner.plan(
            wirds: [wird(id: "old", archived: true)], preferences: WirdReminderPreferences()
        )
        XCTAssertTrue(plan.isEmpty)
    }

    func testToggleOffYieldsNoReminders() {
        let plan = WirdReminderPlanner.plan(
            wirds: [wird(id: "a"), wird(id: "b", createdOffset: 1)],
            preferences: WirdReminderPreferences(enabled: false)
        )
        XCTAssertTrue(plan.isEmpty)
    }

    func testChosenTimeIsCarriedOntoEveryReminder() {
        let plan = WirdReminderPlanner.plan(
            wirds: [wird(id: "a"), wird(id: "b", createdOffset: 1)],
            preferences: WirdReminderPreferences(hour: 6, minute: 45)
        )
        XCTAssertEqual(plan.map(\.hour), [6, 6])
        XCTAssertEqual(plan.map(\.minute), [45, 45])
    }

    /// Overflow past the OS cap evicts the OLDEST pending notifications, which are
    /// the prayer ones — so the budget is a hard ceiling, not a hint.
    func testBudgetCapsTheNumberOfRemindersDeterministically() {
        let wirds = (0..<10).map { wird(id: "w\($0)", createdOffset: TimeInterval($0)) }
        let plan = WirdReminderPlanner.plan(wirds: wirds, preferences: WirdReminderPreferences(), budget: 3)
        XCTAssertEqual(plan.map(\.wirdId), ["w0", "w1", "w2"])

        let again = WirdReminderPlanner.plan(
            wirds: wirds.reversed(), preferences: WirdReminderPreferences(), budget: 3
        )
        XCTAssertEqual(again.map(\.wirdId), plan.map(\.wirdId), "file order must not change who gets a slot")
    }

    func testZeroBudgetYieldsNoReminders() {
        let plan = WirdReminderPlanner.plan(wirds: [wird(id: "a")], preferences: WirdReminderPreferences(), budget: 0)
        XCTAssertTrue(plan.isEmpty)
    }

    func testPreferencesClampOutOfRangeTimes() {
        XCTAssertEqual(WirdReminderPreferences(hour: 99, minute: -5).hour, 23)
        XCTAssertEqual(WirdReminderPreferences(hour: 99, minute: -5).minute, 0)
    }

    func testPreferencesRoundTripThroughJSON() throws {
        let original = WirdReminderPreferences(enabled: false, hour: 7, minute: 30)
        let decoded = try JSONDecoder().decode(
            WirdReminderPreferences.self, from: JSONEncoder().encode(original)
        )
        XCTAssertEqual(decoded, original)
    }

    func testCorruptPreferencesFallBackToDefaultsInsteadOfThrowing() throws {
        let decoded = try JSONDecoder().decode(WirdReminderPreferences.self, from: Data("{}".utf8))
        XCTAssertEqual(decoded, WirdReminderPreferences())
    }

    func testBudgetAfterReserveNeverGoesNegative() {
        XCTAssertEqual(WirdReminderPlanner.budgetAfterReserve(16), 16 - WirdReminderPlanner.notificationReserve)
        XCTAssertEqual(WirdReminderPlanner.budgetAfterReserve(1), 0)
    }
}
