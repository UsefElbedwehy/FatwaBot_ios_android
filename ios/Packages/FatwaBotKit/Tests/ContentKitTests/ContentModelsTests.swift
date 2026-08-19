import XCTest
@testable import ContentKit

final class ContentModelsTests: XCTestCase {

    private func dua(title: String, arabic: String) -> Dua {
        Dua(id: "1", sortOrder: 0, title: title, arabicText: arabic,
            transliteration: nil, translation: nil, source: "حصن المسلم")
    }

    func testDisplayTitlePrefersARealTitle() {
        XCTAssertEqual(dua(title: "دعاء الاستخارة", arabic: "اللهم إني أستخيرك").displayTitle, "دعاء الاستخارة")
    }

    /// Every du'a in the imported Hisn al-Muslim library has an empty title —
    /// this is the case that actually ships.
    func testDisplayTitleFallsBackToTheOpeningWords() {
        let d = dua(title: "", arabic: "((سُبْحَانَ اللَّهِ وَبِحَمْدِهِ)) (مائة مرَّةٍ).")
        XCTAssertFalse(d.displayTitle.isEmpty)
        XCTAssertFalse(d.displayTitle.hasPrefix("("), "recitation marks must be stripped")
        XCTAssertTrue(d.displayTitle.hasPrefix("سُبْحَانَ"))
    }

    func testDisplayTitleTreatsAWhitespaceOnlyTitleAsEmpty() {
        XCTAssertEqual(dua(title: "   ", arabic: "الحمد لله").displayTitle, "الحمد لله")
    }

    func testLongSnippetTruncatesOnAWordBoundary() {
        let long = String(repeating: "كلمة ", count: 40)
        let snippet = dua(title: "", arabic: long).displayTitle
        XCTAssertTrue(snippet.hasSuffix("…"))
        XCTAssertLessThanOrEqual(snippet.count, 49)
        XCTAssertFalse(snippet.dropLast().hasSuffix(" "), "should not end on a dangling space")
    }
}
