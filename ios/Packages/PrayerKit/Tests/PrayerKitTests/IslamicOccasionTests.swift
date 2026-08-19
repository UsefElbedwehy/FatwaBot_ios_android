import XCTest
@testable import PrayerKit

final class IslamicOccasionTests: XCTestCase {
    private let gregorian = Calendar.current

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        gregorian.date(from: DateComponents(year: y, month: m, day: d))!
    }

    private func hijri(of date: Date) -> (month: Int, day: Int) {
        let c = Calendar(identifier: .islamicUmmAlQura).dateComponents([.month, .day], from: date)
        return (c.month ?? 0, c.day ?? 0)
    }

    func testEachOccasionLandsOnItsHijriDate() throws {
        // The load-bearing assertion: whatever Gregorian day we compute, it must
        // actually *be* 1 Ramadan / 1 Shawwal / 10 Dhu al-Hijja.
        let expected: [IslamicOccasion: (Int, Int)] = [
            .ramadan: (9, 1), .eidAlFitr: (10, 1), .eidAlAdha: (12, 10),
        ]
        for (occasion, target) in expected {
            let result = try XCTUnwrap(
                IslamicOccasionCalculator.countdown(to: occasion, from: date(2026, 8, 8))
            )
            let landed = hijri(of: result.gregorianDate)
            XCTAssertEqual(landed.month, target.0, "\(occasion) month")
            XCTAssertEqual(landed.day, target.1, "\(occasion) day")
        }
    }

    func testCountdownIsNeverNegative() throws {
        // Asking on 15 Ramadan must not answer -14. Sampled across a whole year
        // so no single lucky date can pass this.
        var day = date(2026, 1, 1)
        for _ in 0..<370 {
            for occasion in IslamicOccasion.allCases {
                let result = try XCTUnwrap(
                    IslamicOccasionCalculator.countdown(to: occasion, from: day)
                )
                XCTAssertGreaterThanOrEqual(result.daysRemaining, 0)
                XCTAssertLessThan(result.daysRemaining, 366)
            }
            day = gregorian.date(byAdding: .day, value: 1, to: day)!
        }
    }

    func testAnOccasionBeginningTodayReadsZeroRatherThanNextYear() throws {
        // Find the actual first day of Ramadan, then ask from that very day.
        let ramadan = try XCTUnwrap(
            IslamicOccasionCalculator.countdown(to: .ramadan, from: date(2026, 8, 8))
        )
        let onTheDay = try XCTUnwrap(
            IslamicOccasionCalculator.countdown(to: .ramadan, from: ramadan.gregorianDate)
        )
        // `nextDate` searches strictly after its anchor; without the one-second
        // rewind this returns ~354, which would tell a fasting user Ramadan is
        // most of a year away.
        XCTAssertEqual(onTheDay.daysRemaining, 0)
    }

    func testCountdownShrinksByOneEachDay() throws {
        let start = date(2026, 8, 8)
        let today = try XCTUnwrap(IslamicOccasionCalculator.countdown(to: .ramadan, from: start))
        let tomorrow = try XCTUnwrap(
            IslamicOccasionCalculator.countdown(
                to: .ramadan, from: gregorian.date(byAdding: .day, value: 1, to: start)!
            )
        )
        XCTAssertEqual(tomorrow.daysRemaining, today.daysRemaining - 1)
    }

    func testAllIsSortedByProximity() {
        let all = IslamicOccasionCalculator.all(from: date(2026, 8, 8))
        XCTAssertEqual(all.count, 3)
        XCTAssertEqual(all.map(\.daysRemaining), all.map(\.daysRemaining).sorted())
    }

    func testHijriOffsetShiftsTheCountdown() throws {
        let base = try XCTUnwrap(
            IslamicOccasionCalculator.countdown(to: .ramadan, from: date(2026, 8, 8))
        )
        let shifted = try XCTUnwrap(
            IslamicOccasionCalculator.countdown(
                to: .ramadan, from: date(2026, 8, 8), offsetDays: 1
            )
        )
        // A user who has adjusted their Hijri date by a day must not see a
        // countdown computed off the unadjusted calendar sitting next to it.
        XCTAssertEqual(shifted.daysRemaining, base.daysRemaining - 1)
    }

    func testPinnedAgainstAKnownReferenceDate() throws {
        // Cross-platform parity asserted, not assumed: Android uses
        // HijrahChronology and this uses Foundation's islamicUmmAlQura — two
        // independent implementations that could silently diverge by a day. The
        // identical values are pinned in the Android test.
        let from = date(2026, 8, 8)
        let expected: [(IslamicOccasion, Int)] = [
            (.ramadan, 184), (.eidAlFitr, 213), (.eidAlAdha, 281),
        ]
        for (occasion, days) in expected {
            let result = try XCTUnwrap(
                IslamicOccasionCalculator.countdown(to: occasion, from: from)
            )
            XCTAssertEqual(result.daysRemaining, days, "\(occasion)")
        }
        let ramadan = try XCTUnwrap(
            IslamicOccasionCalculator.countdown(to: .ramadan, from: from)
        )
        XCTAssertEqual(
            gregorian.dateComponents([.year, .month, .day], from: ramadan.gregorianDate),
            DateComponents(year: 2027, month: 2, day: 8)
        )
    }
}
