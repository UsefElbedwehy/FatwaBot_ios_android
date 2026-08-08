import XCTest
@testable import ContentKit

final class AzkarItemDecodingTests: XCTestCase {
    private let decoder = JSONDecoder()

    func testDecodesAPayloadWrittenBeforeTitlesExisted() throws {
        // Every install holds a cached azkar payload from before this field
        // existed. A synthesized decoder treats the missing key as an error,
        // rejects the whole collection, and the reader silently falls back to
        // bundled seed with nothing anywhere saying why.
        let payload = Data("""
        {"id":"a","sortOrder":0,"arabicText":"سبحان الله","source":"صحيح البخاري","repeatCount":1}
        """.utf8)
        let item = try decoder.decode(AzkarItem.self, from: payload)
        XCTAssertEqual(item.id, "a")
        XCTAssertNil(item.title)
    }

    func testDecodesATitleWhenTheServerSendsOne() throws {
        let payload = Data("""
        {"id":"a","sortOrder":0,"arabicText":"سبحان الله","title":"التسبيح","source":"","repeatCount":1}
        """.utf8)
        XCTAssertEqual(try decoder.decode(AzkarItem.self, from: payload).title, "التسبيح")
    }

    func testARoundTripPreservesTheTitle() throws {
        let original = AzkarItem(
            id: "a", sortOrder: 0, title: "التسبيح", arabicText: "سبحان الله",
            transliteration: nil, translation: nil, virtueNote: nil,
            source: "صحيح البخاري", repeatCount: 33
        )
        let encoded = try JSONEncoder().encode(original)
        XCTAssertEqual(try decoder.decode(AzkarItem.self, from: encoded), original)
    }
}
