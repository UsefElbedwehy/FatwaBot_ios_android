import XCTest
@testable import AwradFeature

/// `FixedWirdSlots.applied` — the pure seeding rule behind "أضف ورد اليوم"
/// (client decision, 2026-08-12: nothing is seeded automatically anymore; a
/// user opts in with one tap, and the four fixed slots are ordinary wirds
/// after that — tickable, retargetable, deletable).
final class WirdSeedingTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func custom(_ id: String, archivedAt: Date? = nil) -> Wird {
        Wird(
            id: id, name: "ورد مخصص", type: "custom", target: 3, unit: "times",
            frequency: "daily", createdAt: Date(timeIntervalSince1970: 0), archivedAt: archivedAt
        )
    }

    func testAppliedToAnEmptyBoardAddsAllFourSlots() {
        let result = FixedWirdSlots.applied(to: [], now: now)

        XCTAssertEqual(result.count, FixedWirdSlot.allCases.count)
        XCTAssertTrue(result.allSatisfy(\.isFixed))
        XCTAssertTrue(result.allSatisfy(\.isActive))
    }

    func testAppliedPreservesExistingCustomWirds() {
        let result = FixedWirdSlots.applied(to: [custom("mine-1")], now: now)

        XCTAssertTrue(result.contains { $0.id == "mine-1" })
        XCTAssertEqual(result.count, FixedWirdSlot.allCases.count + 1)
    }

    func testAppliedIsIdempotent() {
        let once = FixedWirdSlots.applied(to: [custom("mine-1")], now: now)
        let twice = FixedWirdSlots.applied(to: once, now: now)

        XCTAssertEqual(once, twice)
    }

    func testAppliedDoesNotDuplicateAnAlreadyPresentSlot() {
        let existing = [FixedWirdSlots.wird(for: .qiyamAlLayl, now: now)]
        let result = FixedWirdSlots.applied(to: existing, now: now)

        XCTAssertEqual(result.filter { $0.id == FixedWirdSlot.qiyamAlLayl.wirdId }.count, 1)
        XCTAssertEqual(result.count, FixedWirdSlot.allCases.count)
    }

    /// A fixed slot the user deleted, then asked to add back — re-adding
    /// restores the *same* record (id, createdAt) rather than starting a
    /// duplicate, so its history stays attached.
    func testAppliedReactivatesADeletedFixedSlot() {
        var deleted = FixedWirdSlots.wird(for: .qiyamAlLayl, now: Date(timeIntervalSince1970: 0))
        deleted.archivedAt = Date(timeIntervalSince1970: 100)

        let result = FixedWirdSlots.applied(to: [deleted], now: now)

        let qiyam = result.first { $0.id == FixedWirdSlot.qiyamAlLayl.wirdId }
        XCTAssertNotNil(qiyam)
        XCTAssertTrue(qiyam?.isActive ?? false)
        XCTAssertEqual(qiyam?.createdAt, Date(timeIntervalSince1970: 0), "re-activation must not reset createdAt")
    }

    /// A deleted *custom* wird is left alone — "أضف ورد اليوم" only concerns
    /// the four fixed slots.
    func testAppliedDoesNotReactivateADeletedCustomWird() {
        let deletedCustom = custom("mine-1", archivedAt: Date(timeIntervalSince1970: 100))
        let result = FixedWirdSlots.applied(to: [deletedCustom], now: now)

        XCTAssertEqual(result.first { $0.id == "mine-1" }?.isActive, false)
    }

    // MARK: - normalized (client report: fixed-slot names stuck in the wrong
    // language after a locale switch)

    func testNormalizedRefreshesAFixedSlotNameToTheCurrentResolver() {
        var staleEnglish = FixedWirdSlots.wird(for: .qiyamAlLayl, name: { _ in "Night Prayer (Qiyam)" }, now: now)
        staleEnglish.name = "Night Prayer (Qiyam)"

        let result = FixedWirdSlots.normalized([staleEnglish], name: { _ in "قيام الليل" })

        XCTAssertEqual(result.first?.name, "قيام الليل")
    }

    func testNormalizedLeavesCustomWirdNamesAlone() {
        let mine = custom("mine-1")
        let result = FixedWirdSlots.normalized([mine], name: { _ in "قيام الليل" })

        XCTAssertEqual(result.first?.name, "ورد مخصص")
    }

    func testNormalizedDoesNotAddOrReactivateAnything() {
        let result = FixedWirdSlots.normalized([custom("mine-1")], name: { _ in "قيام الليل" })

        XCTAssertEqual(result.count, 1, "normalized must not seed missing fixed slots")
    }
}
