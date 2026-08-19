import XCTest
@testable import CoreKit

/// The widget→app hand-off fails *silently* when it breaks — the tap just opens
/// Home and nobody notices — so the parsing side is worth pinning down.
final class DeepLinkTests: XCTestCase {
    func testEveryCaseRoundTripsThroughItsURL() {
        for link in DeepLink.allCases {
            XCTAssertEqual(DeepLink(url: link.url), link, "round-trip failed for \(link.rawValue)")
        }
    }

    func testParsesHostForm() {
        XCTAssertEqual(DeepLink(url: URL(string: "fatwabot://dua")!), .dua)
        XCTAssertEqual(DeepLink(url: URL(string: "fatwabot://prayer")!), .prayer)
        XCTAssertEqual(DeepLink(url: URL(string: "fatwabot://journey")!), .journey)
    }

    /// `fatwabot:///dua` has an empty host and a path — accepted so a slightly
    /// malformed link still lands on the right screen.
    func testParsesPathOnlyForm() {
        XCTAssertEqual(DeepLink(url: URL(string: "fatwabot:///dua")!), .dua)
    }

    func testSchemeAndHostAreCaseInsensitive() {
        XCTAssertEqual(DeepLink(url: URL(string: "FATWABOT://DUA")!), .dua)
    }

    func testRejectsForeignSchemes() {
        XCTAssertNil(DeepLink(url: URL(string: "https://fatwabot.app/dua")!))
        XCTAssertNil(DeepLink(url: URL(string: "com.googleusercontent.apps.123://callback")!))
    }

    func testRejectsUnknownRoutes() {
        XCTAssertNil(DeepLink(url: URL(string: "fatwabot://leaderboard")!))
        XCTAssertNil(DeepLink(url: URL(string: "fatwabot://")!))
    }

    /// The scheme is duplicated in ios/App/project.yml (CFBundleURLSchemes).
    /// If someone renames it here, that plist entry must change too.
    func testSchemeIsStable() {
        XCTAssertEqual(DeepLink.scheme, "fatwabot")
        XCTAssertEqual(DeepLink.dua.url.absoluteString, "fatwabot://dua")
    }
}
