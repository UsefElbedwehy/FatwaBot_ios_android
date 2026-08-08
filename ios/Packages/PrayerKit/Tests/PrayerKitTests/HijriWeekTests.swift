import XCTest
@testable import PrayerKit

final class HijriWeekTests: XCTestCase {
    private let gregorian = Calendar.current

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        gregorian.date(from: DateComponents(year: y, month: m, day: d))!
    }

    func testAWeekHasSevenDaysAndExactlyOneToday() {
        let week = HijriWeek.containing(date(2026, 8, 8))
        XCTAssertEqual(week.days.count, 7)
        XCTAssertEqual(week.days.filter(\.isToday).count, 1)
    }

    func testDayNumbersAreConsecutiveWithinAMonth() {
        // Mid-month, so no rollover: the strip must read n, n+1, n+2...
        let week = HijriWeek.containing(date(2026, 8, 8))
        let numbers = week.days.map(\.number)
        if !numbers.contains(1) {
            XCTAssertEqual(numbers, Array(numbers[0]..<(numbers[0] + 7)))
        }
    }

    func testTheStripSurvivesAHijriMonthBoundary() {
        // Walk a whole year and assert the strip is always well-formed. A month
        // rollover is where a Gregorian-derived week goes wrong, and it happens
        // roughly monthly — one sampled date would miss it.
        var day = date(2026, 1, 1)
        for _ in 0..<370 {
            let week = HijriWeek.containing(day)
            XCTAssertEqual(week.days.count, 7)
            XCTAssertEqual(week.days.filter(\.isToday).count, 1)
            XCTAssertTrue(week.days.allSatisfy { $0.number >= 1 && $0.number <= 30 })
            XCTAssertFalse(week.monthName.isEmpty)
            day = gregorian.date(byAdding: .day, value: 1, to: day)!
        }
    }

    func testWeekdayLabelsAlignWithTheirColumns() {
        let week = HijriWeek.containing(date(2026, 8, 8))
        // The label above today's column must be today's actual weekday, or the
        // strip is correct data sitting above the wrong headings.
        let todayIndex = week.days.firstIndex(where: \.isToday)!
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ar")
        let expected = formatter.veryShortWeekdaySymbols![
            gregorian.component(.weekday, from: date(2026, 8, 8)) - 1
        ]
        XCTAssertEqual(week.days[todayIndex].weekdayLabel, expected)
    }

    func testHijriOffsetMovesTheStrip() {
        let base = HijriWeek.containing(date(2026, 8, 8))
        let shifted = HijriWeek.containing(date(2026, 8, 8), offsetDays: 1)
        let baseToday = base.days.first(where: \.isToday)!.number
        let shiftedToday = shifted.days.first(where: \.isToday)!.number
        // A user who adjusted their Hijri date sees the strip move with it.
        XCTAssertNotEqual(baseToday, shiftedToday)
    }
}
