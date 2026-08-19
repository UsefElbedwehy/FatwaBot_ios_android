import XCTest
@testable import DesignSystemKit

/// Arabic pluralisation of the repeat marker.
///
/// This is tested rather than eyeballed because the rule is not the English one
/// and the wrong output is grammatically broken text shown on scripture. The
/// naive `"\(count) مرة"` produces "3 مرة", and the rule that catches people out
/// is that counts above ten revert to the singular — ١٠٠ مرة, not ١٠٠ مرات.
final class RepeatCountLabelTests: XCTestCase {

    private let arabic = Locale(identifier: "ar")

    func testOneIsSuppressed() {
        // Every dhikr is said at least once; a marker saying so on every card
        // is noise that pushes the matn down.
        XCTAssertNil(RepeatCountLabel.text(1, locale: arabic))
    }

    func testZeroAndNegativeAreSuppressed() {
        // Not expected from the corpus, but a bad payload should not render
        // "0 مرة" over a passage of scripture.
        XCTAssertNil(RepeatCountLabel.text(0, locale: arabic))
        XCTAssertNil(RepeatCountLabel.text(-3, locale: arabic))
    }

    func testTwoUsesTheDualAndDropsTheNumeral() {
        // Arabic has a dual form; "مرتان" already means "twice", so printing
        // "2 مرتان" would say two twice.
        XCTAssertEqual(RepeatCountLabel.text(2, locale: arabic), "مرتان")
    }

    func testThreeThroughTenUsePlural() {
        XCTAssertEqual(RepeatCountLabel.text(3, locale: arabic), "3 مرات")
        XCTAssertEqual(RepeatCountLabel.text(7, locale: arabic), "7 مرات")
        XCTAssertEqual(RepeatCountLabel.text(10, locale: arabic), "10 مرات")
    }

    /// The counts this actually protects: 33 after prayer, 100 for istighfar.
    func testElevenAndAboveRevertToSingular() {
        XCTAssertEqual(RepeatCountLabel.text(11, locale: arabic), "11 مرة")
        XCTAssertEqual(RepeatCountLabel.text(33, locale: arabic), "33 مرة")
        XCTAssertEqual(RepeatCountLabel.text(100, locale: arabic), "100 مرة")
    }

    func testNonArabicLocaleUsesTheCompactMarker() {
        XCTAssertEqual(RepeatCountLabel.text(3, locale: Locale(identifier: "en")), "×3")
        XCTAssertEqual(RepeatCountLabel.text(2, locale: Locale(identifier: "en_US")), "×2")
        XCTAssertNil(RepeatCountLabel.text(1, locale: Locale(identifier: "en")))
    }

    /// Regional Arabic still gets Arabic. `hasPrefix("ar")` is the check, so this
    /// pins that "ar_EG" and "ar-SA" are not treated as foreign locales.
    func testRegionalArabicVariantsAreStillArabic() {
        XCTAssertEqual(RepeatCountLabel.text(3, locale: Locale(identifier: "ar_EG")), "3 مرات")
        XCTAssertEqual(RepeatCountLabel.text(3, locale: Locale(identifier: "ar-SA")), "3 مرات")
    }
}
