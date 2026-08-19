import ContentKit
import XCTest
@testable import AzkarFeature

final class AzkarSearchTests: XCTestCase {
    private func item(
        _ id: String, title: String? = nil, arabic: String = "", source: String = ""
    ) -> AzkarItem {
        AzkarItem(
            id: id, sortOrder: 0, title: title, arabicText: arabic,
            transliteration: nil, translation: nil, virtueNote: nil,
            source: source, repeatCount: 1
        )
    }

    func testABlankQueryReturnsEverything() {
        let items = [item("a", arabic: "سبحان الله"), item("b", arabic: "الحمد لله")]
        XCTAssertEqual(AzkarSearch.filter(items, query: "").count, 2)
        XCTAssertEqual(AzkarSearch.filter(items, query: "   ").count, 2)
    }

    func testUnvowelledQueryMatchesFullyVowelledMatn() {
        // The whole reason folding exists. The corpus stores harakat; nobody
        // types them. Without this the search box matches nothing, ever.
        let items = [item("a", arabic: "الْحَمْدُ لِلَّهِ الَّذِي أَحْيَانَا")]
        XCTAssertEqual(AzkarSearch.filter(items, query: "الحمد").count, 1)
    }

    func testAlifVariantsAreInterchangeable() {
        // `أ إ آ ا` are separate codepoints, so this is not fixed by diacritic
        // stripping — and it is the failure a user is most likely to hit,
        // because hamza placement is exactly what people leave off.
        let items = [item("a", arabic: "الإستيقاظ")]
        XCTAssertEqual(AzkarSearch.filter(items, query: "الاستيقاظ").count, 1)
        XCTAssertEqual(AzkarSearch.filter([item("b", arabic: "أذكار")], query: "اذكار").count, 1)
    }

    func testYaAndTaMarbutaVariantsAreInterchangeable() {
        XCTAssertEqual(AzkarSearch.filter([item("a", arabic: "علی")], query: "علي").count, 1)
        XCTAssertEqual(AzkarSearch.filter([item("b", arabic: "رحمة")], query: "رحمه").count, 1)
    }

    func testSearchCoversTitleAndSourceNotJustMatn() {
        let items = [
            item("a", title: "شكر الله على رد الروح", arabic: "الحمد لله"),
            item("b", arabic: "سبحان الله", source: "صحيح البخاري"),
        ]
        XCTAssertEqual(AzkarSearch.filter(items, query: "شكر").map(\.id), ["a"])
        XCTAssertEqual(AzkarSearch.filter(items, query: "البخاري").map(\.id), ["b"])
    }

    func testAnUntitledCorpusIsStillSearchable() {
        // The state the library is actually in today: no titles anywhere. If
        // matn were excluded from matching, search would return nothing for
        // every query and look broken rather than empty.
        let items = [item("a", arabic: "اللَّهُمَّ أَعِنِّي عَلَى ذِكْرِكَ")]
        XCTAssertTrue(items.allSatisfy { $0.title == nil })
        XCTAssertEqual(AzkarSearch.filter(items, query: "ذكرك").count, 1)
    }

    func testNoMatchReturnsEmptyRatherThanEverything() {
        let items = [item("a", arabic: "سبحان الله")]
        XCTAssertTrue(AzkarSearch.filter(items, query: "قنديل").isEmpty)
    }

    func testLatinSearchIsCaseInsensitive() {
        let items = [item("a", source: "Sahih Bukhari")]
        XCTAssertEqual(AzkarSearch.filter(items, query: "bukhari").count, 1)
    }
}
