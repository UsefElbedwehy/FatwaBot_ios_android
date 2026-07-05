import XCTest
import CoreKit
import NetworkingKit
@testable import ContentKit

/// Spec: docs/features/content-pipeline.md — the four required cases.
final class ContentServiceTests: XCTestCase {
    final class StubClient: APIClientProtocol, @unchecked Sendable {
        var responses: [String: Data] = [:]

        func get<Response: Decodable & Sendable>(_ endpoint: Endpoint<Response>) async throws -> Response {
            guard let data = responses[endpoint.path] else {
                throw APIError.transport("stubbed failure for \(endpoint.path)")
            }
            return try JSONDecoder().decode(Response.self, from: data)
        }
    }

    private func tempStore() -> ContentFileStore {
        ContentFileStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
    }

    // MARK: - Case 1: first launch, no network -> bundled seed renders

    func testFirstLaunchOfflineRendersBundledSeed() async {
        let service = ContentService(store: tempStore(), client: StubClient())
        let azkar = await service.azkar(locale: "ar")
        XCTAssertNotNil(azkar, "bundled seed must render with zero network")
        XCTAssertFalse(azkar?.categories.isEmpty ?? true)
        XCTAssertEqual(azkar?.categories.first?.slug, "morning")

        let duas = await service.duas(locale: "ar")
        XCTAssertFalse(duas?.categories.isEmpty ?? true)

        let hadith = await service.hadithCollections(locale: "ar")
        XCTAssertFalse(hadith.isEmpty)

        let wird = await service.wirdTemplates(locale: "ar")
        XCTAssertFalse(wird?.templates.isEmpty ?? true)
    }

    // MARK: - Case 2: refresh with new version applies and persists

    func testRefreshAppliesNewerVersionAndPersists() async throws {
        let store = tempStore()
        let client = StubClient()
        let payload = """
        {"version": 999, "categories": [{"id": "x", "slug": "test", "name": "Test", "sortOrder": 0, "items": []}]}
        """
        client.responses["v1/content/azkar"] = Data(payload.utf8)
        let service = ContentService(store: store, client: client)

        let changed = await service.refreshAzkar(locale: "ar")
        XCTAssertTrue(changed)
        let updated = await service.azkar(locale: "ar")
        XCTAssertEqual(updated?.version, 999)

        // A second service instance backed by the same store sees the persisted value.
        let reloaded = ContentService(store: store, client: StubClient())
        let fromDisk = await reloaded.azkar(locale: "ar")
        XCTAssertEqual(fromDisk?.version, 999)
    }

    func testRefreshWithUnchangedVersionReportsNoChange() async {
        let store = tempStore()
        let client = StubClient()
        let payload = "{\"version\": 1, \"categories\": []}"
        client.responses["v1/content/azkar"] = Data(payload.utf8)
        let service = ContentService(store: store, client: client)

        _ = await service.refreshAzkar(locale: "ar")
        let secondRefresh = await service.refreshAzkar(locale: "ar")
        XCTAssertFalse(secondRefresh, "identical payload should report no change")
    }

    // MARK: - Case 3: malformed response leaves cache untouched

    func testMalformedResponseLeavesCacheUntouched() async {
        let store = tempStore()
        let client = StubClient()
        client.responses["v1/content/azkar"] = Data("{not json".utf8)
        let service = ContentService(store: store, client: client)

        let before = await service.azkar(locale: "ar") // bundled seed
        let changed = await service.refreshAzkar(locale: "ar")
        let after = await service.azkar(locale: "ar")

        XCTAssertFalse(changed)
        XCTAssertEqual(before, after, "malformed refresh must not corrupt or clear the cache")
    }

    // MARK: - Case 4: locale switch uses a separate cache entry

    func testLocaleSwitchDoesNotCrossContaminate() async {
        let store = tempStore()
        let client = StubClient()
        client.responses["v1/content/azkar"] = Data(
            "{\"version\": 5, \"categories\": [{\"id\":\"en-cat\",\"slug\":\"s\",\"name\":\"English\",\"sortOrder\":0,\"items\":[]}]}"
                .utf8
        )
        let service = ContentService(store: store, client: client)

        _ = await service.refreshAzkar(locale: "en")
        let en = await service.azkar(locale: "en")
        let ar = await service.azkar(locale: "ar") // untouched, still bundled seed

        XCTAssertEqual(en?.version, 5)
        XCTAssertNotEqual(ar?.version, 5)
        XCTAssertEqual(ar?.categories.first?.slug, "morning", "ar cache must be unaffected by an en refresh")
    }
}
