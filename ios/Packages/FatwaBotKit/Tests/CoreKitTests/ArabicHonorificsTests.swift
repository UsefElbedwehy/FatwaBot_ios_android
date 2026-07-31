import XCTest
@testable import CoreKit

final class ArabicHonorificsTests: XCTestCase {

    func testExpandsTheMostCommonHonorific() {
        // U+FD41, 738 occurrences in بلوغ المرام alone.
        XCTAssertEqual("عَنْ أَبِي هُرَيْرَةَ \u{FD41}".expandingArabicHonorifics,
                       "عَنْ أَبِي هُرَيْرَةَ رضي الله عنه")
    }

    func testInsertsASpaceWhenTheGlyphAbutsTheWord() {
        // The corpus writes the ligature tight against the name; expanding
        // without a space would weld it onto the preceding word.
        XCTAssertEqual("عَائِشَةُ\u{FD42}".expandingArabicHonorifics, "عَائِشَةُ رضي الله عنها")
    }

    func testDoesNotDoubleUpAnExistingSpace() {
        XCTAssertEqual("عَائِشَةُ \u{FD42}".expandingArabicHonorifics, "عَائِشَةُ رضي الله عنها")
    }

    func testLeavesRenderableLigaturesAlone() {
        // ﷺ (U+FDFA) predates Unicode 14 and every Arabic font draws it — the
        // ligature is the form readers expect, so it must survive untouched.
        let text = "قَالَ رَسُولُ اللَّهِ \u{FDFA}"
        XCTAssertEqual(text.expandingArabicHonorifics, text)
    }

    func testIsANoOpForTextWithoutHonorifics() {
        let text = "إِنَّمَا الأَعْمَالُ بِالنِّيَّاتِ"
        XCTAssertEqual(text.expandingArabicHonorifics, text)
    }

    func testExpandsEveryMappedCodepointToNonEmptyArabic() {
        for (character, expansion) in ArabicHonorifics.expansions {
            XCTAssertFalse(expansion.isEmpty, "U+\(String(character.unicodeScalars.first!.value, radix: 16)) is empty")
            // Guard against a mapping accidentally holding another ligature.
            XCTAssertNil(ArabicHonorifics.expansions[Character(expansion.first!.description)])
        }
    }

    func testHandlesSeveralHonorificsInOneString() {
        let input = "\u{FD41} ثُمَّ \u{FD44}"
        XCTAssertEqual(input.expandingArabicHonorifics, "رضي الله عنه ثُمَّ رضي الله عنهما")
    }
}
