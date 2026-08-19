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

// MARK: - Takhrij trimming

final class HadithDisplayTests: XCTestCase {

    func testRemovesTheTrailingTakhrij() {
        let matn = "«هُوَ الطَّهُورُ مَاؤُهُ الْحِلُّ مَيْتَتُهُ» أَخْرَجَهُ الْأَرْبَعَةُ."
        XCTAssertEqual(
            HadithDisplay.matnWithoutTakhrij(matn, grading: "أَخْرَجَهُ الْأَرْبَعَةُ."),
            "«هُوَ الطَّهُورُ مَاؤُهُ الْحِلُّ مَيْتَتُهُ»"
        )
    }

    func testLeavesTheMatnAloneWhenTheGradingIsAuthoredRatherThanQuoted() {
        // العمدة's stamped grading appears nowhere in its text (migration 0030).
        let matn = "قَالَ رَسُولُ اللَّهِ: «وَيْلٌ لِلْأَعْقَابِ مِنَ النَّارِ»."
        XCTAssertEqual(HadithDisplay.matnWithoutTakhrij(matn, grading: "مُتَّفَقٌ عَلَيْهِ."), matn)
    }

    func testDoesNotCutMidTextWhenCommentaryFollows() {
        // Removing a non-suffix clause would leave a hole mid-sentence, so this
        // deliberately shows the takhrij twice instead.
        let matn = "«وَلْيَضَعْ يَدَيْهِ» أَخْرَجَهُ الثَّلَاثَةُ. وَهُوَ أَقْوَى مِنْ حَدِيثِ وَائِلٍ."
        XCTAssertEqual(
            HadithDisplay.matnWithoutTakhrij(matn, grading: "أَخْرَجَهُ الثَّلَاثَةُ."),
            matn.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        )
    }

    func testKeepsTheMatnWhenTrimmingWouldEmptyIt() {
        let matn = "مُتَّفَقٌ عَلَيْهِ."
        XCTAssertEqual(HadithDisplay.matnWithoutTakhrij(matn, grading: "مُتَّفَقٌ عَلَيْهِ."), matn)
    }

    func testEmptyGradingIsANoOp() {
        let matn = "إِنَّمَا الأَعْمَالُ بِالنِّيَّاتِ."
        XCTAssertEqual(HadithDisplay.matnWithoutTakhrij(matn, grading: ""), matn)
    }

    func testToleratesWhitespaceDifferencesBetweenStoredMatnAndGrading() {
        // The grading was extracted from whitespace-normalized text, so the
        // stored matn can differ in spacing and must still match.
        let matn = "«الْمَتْنُ»   أَخْرَجَهُ\nمُسْلِمٌ."
        XCTAssertEqual(
            HadithDisplay.matnWithoutTakhrij(matn, grading: "أَخْرَجَهُ مُسْلِمٌ."),
            "«الْمَتْنُ»"
        )
    }
}
