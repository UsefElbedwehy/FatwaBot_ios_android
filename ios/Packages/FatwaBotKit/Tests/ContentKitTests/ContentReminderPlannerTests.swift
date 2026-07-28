import CoreKit
import XCTest
@testable import ContentKit

/// Mirrors Android `ContentReminderPlannerTest` — both planners must behave identically.
final class ContentReminderPlannerTests: XCTestCase {
    /// Fixed zone so the waking-window assertions don't depend on the test machine.
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Riyadh")!
        c.locale = Locale(identifier: "en_US_POSIX")
        return c
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private func pool(_ prefix: String, _ count: Int, wordCount: Int = 4) -> [ContentSnippet] {
        (0..<count).map { index in
            ContentSnippet(
                id: "\(prefix)-\(index)",
                text: Array(repeating: "\(prefix)\(index)", count: wordCount).joined(separator: " ")
            )
        }
    }

    private func plan(
        perDay: Int = 2,
        enabled: Bool = true,
        azkar: [ContentSnippet]? = nil,
        hadith: [ContentSnippet]? = nil,
        now: Date? = nil,
        horizonDays: Int = ContentReminderPlanner.defaultHorizonDays,
        budget: Int = ContentReminderPlanner.defaultBudget
    ) -> [PlannedContentReminder] {
        ContentReminderPlanner.plan(
            azkar: azkar ?? pool("zikr", 12),
            hadith: hadith ?? pool("hadith", 9),
            preferences: ContentReminderPreferences(enabled: enabled, perDay: perDay),
            now: now ?? date(2026, 7, 28, 0, 30),
            calendar: calendar,
            horizonDays: horizonDays,
            budget: budget
        )
    }

    // MARK: - Determinism

    /// The whole reason the RNG is seeded: re-planning happens on every launch
    /// and every settings change, and it must be a no-op, not a reshuffle.
    func testRepeatedPlanningOfTheSameDayIsIdentical() {
        let first = plan()
        let second = plan()
        XCTAssertFalse(first.isEmpty)
        XCTAssertEqual(first, second)
    }

    /// Planning later the same day must not move the reminders that are still
    /// ahead — it may only drop the ones that have already fired. Horizon and
    /// budget are set so the budget doesn't bind: at the cap, dropping the
    /// elapsed reminders legitimately pulls in later days that weren't in the
    /// first plan, which would make the subset assertion below meaningless.
    func testLaterReplanKeepsTheSurvivingRemindersUnmoved() {
        let morning = plan(perDay: 5, now: date(2026, 7, 28, 0, 30), horizonDays: 2, budget: 64)
        let afternoon = plan(perDay: 5, now: date(2026, 7, 28, 15, 0), horizonDays: 2, budget: 64)
        XCTAssertLessThan(afternoon.count, morning.count)
        let byID = Dictionary(uniqueKeysWithValues: morning.map { ($0.id, $0) })
        for item in afternoon {
            XCTAssertEqual(byID[item.id]?.fireDate, item.fireDate)
            XCTAssertEqual(byID[item.id]?.contentID, item.contentID)
        }
    }

    /// Different days must not all land on the same clock time.
    func testDifferentDaysGetDifferentTimes() {
        let all = plan(perDay: 1, horizonDays: 7, budget: 16)
        let minutes = Set(all.map { calendar.component(.hour, from: $0.fireDate) * 60 + calendar.component(.minute, from: $0.fireDate) })
        XCTAssertGreaterThan(minutes.count, 1)
    }

    // MARK: - Count

    func testZeroPerDayEmitsNothing() {
        XCTAssertTrue(plan(perDay: 0).isEmpty)
    }

    func testDisabledToggleEmitsNothingEvenWithANonZeroCount() {
        XCTAssertTrue(plan(perDay: 5, enabled: false).isEmpty)
    }

    func testFivePerDayEmitsFivePerDay() {
        let all = plan(perDay: 5, horizonDays: 3, budget: 100)
        let firstDay = all.filter { calendar.isDate($0.fireDate, inSameDayAs: date(2026, 7, 28)) }
        XCTAssertEqual(firstDay.count, 5)
        XCTAssertEqual(all.count, 15)
    }

    func testCountIsClampedToTheAllowedRange() {
        XCTAssertEqual(ContentReminderPreferences(perDay: 99).perDay, 5)
        XCTAssertEqual(ContentReminderPreferences(perDay: -3).perDay, 0)
    }

    /// The advertised default: two a day, one azkar and one hadith.
    func testDefaultIsOneAzkarAndOneHadithPerDay() {
        let all = plan(horizonDays: 3, budget: 100)
        let firstDay = all.filter { calendar.isDate($0.fireDate, inSameDayAs: date(2026, 7, 28)) }
        XCTAssertEqual(firstDay.count, 2)
        XCTAssertEqual(Set(firstDay.map(\.kind)), [.azkar, .hadith])
    }

    // MARK: - Waking window

    func testEveryFireTimeIsInsideTheWakingWindow() {
        for count in 1...5 {
            for item in plan(perDay: count, horizonDays: 7, budget: 64) {
                let hour = calendar.component(.hour, from: item.fireDate)
                XCTAssertGreaterThanOrEqual(hour, ContentReminderPlanner.windowStartHour, "\(item.id)")
                XCTAssertLessThan(hour, ContentReminderPlanner.windowEndHour, "\(item.id)")
            }
        }
    }

    func testRemindersAreSortedAndNeverInThePast() {
        let now = date(2026, 7, 28, 13, 20)
        let all = plan(perDay: 4, now: now, horizonDays: 4, budget: 64)
        XCTAssertEqual(all, all.sorted { $0.fireDate < $1.fireDate })
        XCTAssertTrue(all.allSatisfy { $0.fireDate > now })
    }

    // MARK: - Budget

    /// iOS drops the OLDEST pending requests past 64, which would silently delete
    /// prayer notifications — so overshooting here is a real bug, not cosmetic.
    func testNeverExceedsTheRemainingBudget() {
        let all = plan(perDay: 5, horizonDays: 14)
        XCTAssertEqual(all.count, ContentReminderPlanner.defaultBudget)
        XCTAssertLessThanOrEqual(all.count, 16)
    }

    func testRemainingBudgetIsWhatThePrayerScheduleLeavesOver() {
        // PrayerKit's NotificationPlanner.iosBudget is 48 of the OS's 64.
        XCTAssertEqual(ContentReminderPlanner.remainingBudget(prayerReserve: 48), 16)
        XCTAssertEqual(ContentReminderPlanner.defaultBudget, 16)
        XCTAssertEqual(ContentReminderPlanner.remainingBudget(prayerReserve: 64), 0)
        XCTAssertEqual(ContentReminderPlanner.remainingBudget(prayerReserve: 999), 0)
    }

    func testZeroBudgetEmitsNothing() {
        XCTAssertTrue(plan(perDay: 5, budget: 0).isEmpty)
    }

    // MARK: - Empty pools

    func testBothPoolsEmptyYieldsNothingRatherThanCrashing() {
        XCTAssertTrue(plan(azkar: [], hadith: []).isEmpty)
    }

    func testOneEmptyPoolFallsBackToTheOther() {
        let all = plan(perDay: 4, azkar: [], horizonDays: 2, budget: 64)
        XCTAssertFalse(all.isEmpty)
        XCTAssertTrue(all.allSatisfy { $0.kind == .hadith })

        let azkarOnly = plan(perDay: 4, hadith: [], horizonDays: 2, budget: 64)
        XCTAssertFalse(azkarOnly.isEmpty)
        XCTAssertTrue(azkarOnly.allSatisfy { $0.kind == .azkar })
    }

    // MARK: - Truncation

    func testLongTextIsTruncatedAtAWordBoundary() {
        let words = Array(repeating: "الحمد", count: 60)
        let long = words.joined(separator: " ")
        let short = ContentReminderPlanner.truncate(long)

        XCTAssertLessThanOrEqual(short.count, ContentReminderPlanner.bodyCharacterLimit)
        XCTAssertTrue(short.hasSuffix("…"))
        // Every surviving token must be a whole word from the source — i.e. the
        // cut landed on a space, not in the middle of "الحمد".
        let kept = short.dropLast().trimmingCharacters(in: .whitespaces).split(separator: " ")
        XCTAssertFalse(kept.isEmpty)
        XCTAssertTrue(kept.allSatisfy { $0 == "الحمد" })
    }

    func testShortTextIsLeftAloneApartFromCollapsedWhitespace() {
        XCTAssertEqual(ContentReminderPlanner.truncate("سبحان   الله\nوبحمده"), "سبحان الله وبحمده")
    }

    /// A single token longer than the limit has no boundary to cut on, so it is
    /// hard-cut rather than returned whole (which would blow past the limit).
    func testAWordLongerThanTheLimitIsHardCut() {
        let giant = String(repeating: "x", count: 400)
        let short = ContentReminderPlanner.truncate(giant, limit: 20)
        XCTAssertEqual(short.count, 20)
        XCTAssertTrue(short.hasSuffix("…"))
    }

    func testPlannedBodiesRespectTheLimit() {
        let wordy = [ContentSnippet(id: "h1", text: Array(repeating: "كلمة", count: 200).joined(separator: " "))]
        let all = plan(perDay: 2, azkar: wordy, hadith: wordy, horizonDays: 3, budget: 64)
        XCTAssertFalse(all.isEmpty)
        XCTAssertTrue(all.allSatisfy { $0.body.count <= ContentReminderPlanner.bodyCharacterLimit })
    }

    // MARK: - Deep links

    func testEachKindPointsAtItsOwnScreen() {
        XCTAssertEqual(PlannedContentReminder.Kind.azkar.deepLink, DeepLink.azkar)
        XCTAssertEqual(PlannedContentReminder.Kind.hadith.deepLink, DeepLink.hadith)
        let all = plan(horizonDays: 2, budget: 64)
        for item in all {
            XCTAssertEqual(item.deepLink, item.kind == .azkar ? .azkar : .hadith)
        }
    }

    // MARK: - Identifiers

    func testIdentifiersAreStableAndUnique() {
        let all = plan(perDay: 5, horizonDays: 3, budget: 64)
        XCTAssertEqual(Set(all.map(\.id)).count, all.count)
        XCTAssertTrue(all.allSatisfy { $0.id.hasPrefix("content-") })
    }

    // MARK: - Cross-platform parity

    /// The seeded hash is the contract between the two platforms: if these drift,
    /// the same user gets different schedules on iPhone and Android. The last two
    /// inputs are the real `dayKey * 64 + slot` seeds for 2026-07-28, slots 0/1.
    /// Asserted identically in Android's `ContentReminderPlannerTest`.
    func testSplitmix64MatchesTheAndroidImplementation() {
        XCTAssertEqual(ContentReminderPlanner.splitmix64(0), 0xE220_A839_7B1D_CDAF)
        XCTAssertEqual(ContentReminderPlanner.splitmix64(1), 0x910A_2DEC_8902_5CC1)
        XCTAssertEqual(ContentReminderPlanner.splitmix64(0x9E37_79B9_7F4A_7C15), 0x6E78_9E6A_A1B9_65F4)
        XCTAssertEqual(ContentReminderPlanner.splitmix64(20_260_728 * 64), 0x09C3_DAC5_32F5_D995)
        XCTAssertEqual(ContentReminderPlanner.splitmix64(20_260_728 * 64 + 1), 0xEDA8_B995_16FA_22CE)
    }

    // MARK: - Preferences persistence

    func testPreferencesRoundTripThroughJSON() throws {
        let original = ContentReminderPreferences(enabled: false, perDay: 4)
        let data = try JSONEncoder().encode(original)
        XCTAssertEqual(try JSONDecoder().decode(ContentReminderPreferences.self, from: data), original)
    }

    /// A stored blob written before this feature existed must not reset the user.
    func testDecodingAnEmptyObjectFallsBackToTheDefaults() throws {
        let decoded = try JSONDecoder().decode(
            ContentReminderPreferences.self, from: Data("{}".utf8)
        )
        XCTAssertEqual(decoded, ContentReminderPreferences())
        XCTAssertEqual(decoded.perDay, 2)
        XCTAssertTrue(decoded.enabled)
    }
}
