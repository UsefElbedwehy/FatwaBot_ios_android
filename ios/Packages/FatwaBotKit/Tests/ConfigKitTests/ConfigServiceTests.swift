import XCTest
import CoreKit
import NetworkingKit
@testable import ConfigKit

/// Spec: docs/features/config-sync.md — the five required cases.
final class ConfigServiceTests: XCTestCase {
    // MARK: - Test doubles

    final class InMemoryStore: ConfigStoring, @unchecked Sendable {
        private let lock = NSLock()
        private var snapshot: ConfigSnapshot?
        var saveCount = 0

        init(initial: ConfigSnapshot? = nil) { self.snapshot = initial }

        func load() -> ConfigSnapshot? {
            lock.withLock { snapshot }
        }

        func save(_ new: ConfigSnapshot) {
            lock.withLock {
                snapshot = new
                saveCount += 1
            }
        }
    }

    /// Path-keyed stub client; a missing entry throws (simulating failure),
    /// a `Data` entry decodes as the response.
    final class StubClient: APIClientProtocol, @unchecked Sendable {
        var responses: [String: Data] = [:]

        func get<Response: Decodable & Sendable>(_ endpoint: Endpoint<Response>) async throws -> Response {
            guard let data = responses[endpoint.path] else {
                throw APIError.transport("stubbed failure for \(endpoint.path)")
            }
            return try JSONDecoder().decode(Response.self, from: data)
        }
    }

    private func fullResponses() -> [String: Data] {
        [
            "v1/config": Data("""
            {"config": {"x": 1},
             "flags": {"module.prayer": {"enabled": true, "rollout": {}},
                       "module.ai_ask": {"enabled": true, "rollout": {"min_app_version": "2.0.0"}}},
             "locales": [{"locale": "ar", "display_name": "العربية", "direction": "rtl", "digits": "eastern"}]}
            """.utf8),
            "v1/config/theme": Data(#"{"version": 4, "tokens": {"product_name": "Companion"}}"#.utf8),
            "v1/home": Data(#"{"version": 2, "sections": [{"id": "p", "type": "prayer_hero", "props": {}}]}"#.utf8),
            "v1/config/strings/ar": Data(#"{"locale": "ar", "version": 7, "strings": {"k": "قيمة"}}"#.utf8),
        ]
    }

    // MARK: - Spec case 1: first launch, no network

    func testFirstLaunchOfflineYieldsEmptySnapshotWithoutError() async {
        let service = ConfigService(store: InMemoryStore(), client: StubClient())
        let snapshot = await service.current
        XCTAssertNil(snapshot.appConfig)
        let changed = await service.refresh(locales: ["ar"])
        XCTAssertEqual(changed, [], "total network failure must be silent")
    }

    // MARK: - Spec case 2: refresh persists and reports changed layers

    func testRefreshPersistsChangedLayers() async {
        let store = InMemoryStore()
        let client = StubClient()
        client.responses = fullResponses()
        let service = ConfigService(store: store, client: client)

        let changed = await service.refresh(locales: ["ar"])
        XCTAssert(changed.contains(.appConfig))
        XCTAssert(changed.contains(.theme))
        XCTAssert(changed.contains(.homeLayout))
        XCTAssert(changed.contains(.strings))
        XCTAssertEqual(store.saveCount, 1)
        XCTAssertEqual(store.load()?.theme?.version, 4)

        // Second refresh with identical payloads: nothing changes, nothing saved.
        let again = await service.refresh(locales: ["ar"])
        XCTAssertEqual(again, [])
        XCTAssertEqual(store.saveCount, 1)
    }

    // MARK: - Spec case 3: malformed layer never corrupts others

    func testMalformedLayerLeavesOtherLayersApplied() async {
        let store = InMemoryStore()
        let client = StubClient()
        client.responses = fullResponses()
        client.responses["v1/config/theme"] = Data("{not json".utf8)
        let service = ConfigService(store: store, client: client)

        let changed = await service.refresh(locales: ["ar"])
        XCTAssertFalse(changed.contains(.theme))
        XCTAssert(changed.contains(.appConfig), "healthy layers still apply")
        XCTAssertNil(store.load()?.theme)
        XCTAssertNotNil(store.load()?.appConfig)
    }

    // MARK: - Spec case 4: string-pack delta

    func testUpToDateStringPackLeavesOverlayUnchanged() async {
        let cached = ConfigSnapshot(
            stringPacks: ["ar": StringPack(locale: "ar", version: 7, strings: ["k": "قيمة"])],
            fetchedAt: Date(timeIntervalSince1970: 0)
        )
        let client = StubClient() // strings endpoint fails → cached pack stays
        let service = ConfigService(store: InMemoryStore(initial: cached), client: client)
        _ = await service.refresh(locales: ["ar"])
        let value = await service.string("k", locale: "ar")
        XCTAssertEqual(value, "قيمة")
    }

    // MARK: - Spec case 5 (variant): flag gating with version gates

    func testFlagGatingHonorsMinAppVersion() async {
        let client = StubClient()
        client.responses = fullResponses()
        let service = ConfigService(store: InMemoryStore(), client: client)
        _ = await service.refresh(locales: [])

        let prayerOn = await service.isEnabled("module.prayer", appVersion: "0.1.0")
        let askOld = await service.isEnabled("module.ai_ask", appVersion: "1.9.9")
        let askNew = await service.isEnabled("module.ai_ask", appVersion: "2.0.1")
        let unknown = await service.isEnabled("module.nope", appVersion: "9.9.9")
        XCTAssertTrue(prayerOn)
        XCTAssertFalse(askOld, "enabled flag below min_app_version must gate off")
        XCTAssertTrue(askNew)
        XCTAssertFalse(unknown)
    }

    func testSemVerComparisons() {
        XCTAssertTrue(SemVer.isVersion("1.2.10", atLeast: "1.2.9"))
        XCTAssertTrue(SemVer.isVersion("1.2", atLeast: "1.2.0"))
        XCTAssertFalse(SemVer.isVersion("1.2.0", atLeast: "1.10"))
        XCTAssertTrue(SemVer.isVersion("2.0.0", atLeast: "2"))
    }
}
