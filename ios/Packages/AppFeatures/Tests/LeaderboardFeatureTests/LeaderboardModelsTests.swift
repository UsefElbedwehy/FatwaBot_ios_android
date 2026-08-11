import XCTest
@testable import LeaderboardFeature

/// Round-trip JSON decode tests for `LeaderboardBoard`. `LeaderboardViewModelTests`
/// exercises the view model against a fake client that hands back already-built
/// Swift structs, so it never touches `JSONDecoder` — nothing there would catch a
/// `CodingKeys` typo or a date-format mismatch against what the backend actually
/// sends. These decode raw JSON directly to close that gap.
final class LeaderboardModelsTests: XCTestCase {
    private func decode(_ json: String) throws -> LeaderboardBoard {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601 // matches AuthenticatedAPIClient's decoder
        return try decoder.decode(LeaderboardBoard.self, from: Data(json.utf8))
    }

    func testDecodesPeriodBoundsFromTheBackendsMillisecondFormat() throws {
        // `Date.prototype.toISOString()` on the backend always emits milliseconds
        // ("2026-01-01T00:00:00.000Z"), unlike the plain-second examples in most
        // ISO 8601 docs. This pins that the app's decoder actually accepts that.
        let board = try decode("""
        {
          "key": "consistency_global", "name": "Global", "scope": "global",
          "period": "halfyearly", "joined": false, "my_rank": null, "entries": [],
          "period_starts_at": "2026-01-01T00:00:00.000Z",
          "period_ends_at": "2026-07-01T00:00:00.000Z"
        }
        """)
        XCTAssertEqual(board.periodStartsAt, ISO8601DateFormatter().date(from: "2026-01-01T00:00:00Z"))
        XCTAssertEqual(board.periodEndsAt, ISO8601DateFormatter().date(from: "2026-07-01T00:00:00Z"))
    }

    func testMissingPeriodBoundsDecodeAsNilRatherThanFailing() throws {
        // A `lifetime` board's bounds are genuinely absent (`null` on the wire,
        // per `periodBoundsFor`), not an omitted key — this is the shape a real
        // lifetime board sends, and it must not fail the whole board's decode.
        let board = try decode("""
        {
          "key": "old_board", "name": "Old Board", "scope": "global",
          "period": "lifetime", "joined": false, "my_rank": null, "entries": [],
          "period_starts_at": null, "period_ends_at": null
        }
        """)
        XCTAssertNil(board.periodStartsAt)
        XCTAssertNil(board.periodEndsAt)
    }

    func testDecodesCleanlyWhenTheKeysAreAbsentEntirely() throws {
        // Belt-and-suspenders against a server that omits the keys outright
        // rather than sending explicit nulls — optional Decodable properties
        // tolerate a missing key the same as an explicit null.
        let board = try decode("""
        {
          "key": "old_board", "name": "Old Board", "scope": "global",
          "period": "lifetime", "joined": false, "my_rank": null, "entries": []
        }
        """)
        XCTAssertNil(board.periodStartsAt)
        XCTAssertNil(board.periodEndsAt)
    }
}
