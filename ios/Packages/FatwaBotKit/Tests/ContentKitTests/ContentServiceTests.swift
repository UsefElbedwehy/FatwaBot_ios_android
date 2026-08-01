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
        XCTAssertEqual(changed, .updated)
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
        XCTAssertEqual(secondRefresh, .unchanged, "identical payload should report no change")
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

        // A malformed payload is now a *reported* failure, not a silent no-op.
        XCTAssertTrue(changed.isFailure)
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

    // MARK: - A failed sync must not look like a healthy one

    func testAFailedRefreshIsReportedRatherThanSwallowed() async {
        // The stub throws for any path it has no response for.
        let service = ContentService(store: tempStore(), client: StubClient())
        let outcome = await service.refreshAzkar(locale: "ar")

        XCTAssertTrue(outcome.isFailure, "a transport error must surface as .failed")
        XCTAssertNotEqual(outcome, .unchanged, "the bug: failure was indistinguishable from no-change")
        let failures = await service.lastFailures
        XCTAssertNotNil(failures["azkar.ar"], "the failure must be recorded for diagnostics")
    }

    func testASuccessfulRefreshClearsAPreviousFailure() async {
        let client = StubClient()
        let service = ContentService(store: tempStore(), client: client)

        _ = await service.refreshAzkar(locale: "ar")
        var failures = await service.lastFailures
        XCTAssertNotNil(failures["azkar.ar"])

        client.responses["v1/content/azkar"] = Data("{\"version\": 2, \"categories\": []}".utf8)
        let outcome = await service.refreshAzkar(locale: "ar")

        XCTAssertEqual(outcome, .updated)
        failures = await service.lastFailures
        XCTAssertNil(failures["azkar.ar"], "a recovered endpoint must not stay marked broken")
    }

    func testSyncSummaryDistinguishesUpdatedFromFailed() async {
        let client = StubClient()
        // Only azkar answers; everything else throws.
        client.responses["v1/content/azkar"] = Data("{\"version\": 9, \"categories\": []}".utf8)
        let service = ContentService(store: tempStore(), client: client)

        let summary = await service.syncAll(locale: "ar")
        XCTAssertTrue(summary.updated.contains("azkar"))
        XCTAssertTrue(summary.hasFailures, "unreachable endpoints must be reported")
        XCTAssertTrue(summary.failed.contains("duas"))
    }

    func testUpToDateEnvelopeIsUnchangedNotFailed() async {
        // The API answers an already-current request with {"up_to_date": true},
        // which cannot decode as the payload. That must read as success — the
        // Settings row otherwise reports every healthy collection as failed.
        let client = StubClient()
        client.responses["v1/content/azkar"] = Data("{\"up_to_date\": true}".utf8)
        let service = ContentService(store: tempStore(), client: client)

        let outcome = await service.refreshAzkar(locale: "ar")
        XCTAssertEqual(outcome, .unchanged)
        let failures = await service.lastFailures
        XCTAssertNil(failures["azkar.ar"])
    }

    func testAGenuinelyMalformedPayloadStillFails() async {
        // The up-to-date check must stay narrow enough to let real corruption
        // through — otherwise it trades one silent failure for another.
        let client = StubClient()
        client.responses["v1/content/azkar"] = Data("{\"version\": \"not-a-number\"}".utf8)
        let service = ContentService(store: tempStore(), client: client)

        let outcome = await service.refreshAzkar(locale: "ar")
        XCTAssertTrue(outcome.isFailure)
    }
}
