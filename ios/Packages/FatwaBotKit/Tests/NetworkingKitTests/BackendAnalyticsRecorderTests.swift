import CoreKit
import Foundation
import XCTest
@testable import NetworkingKit

/// In-memory queue store, so tests don't touch disk.
private final class MemoryQueueStore: AnalyticsEventQueueStoring, @unchecked Sendable {
    var events: [QueuedAnalyticsEvent] = []
    func load() -> [QueuedAnalyticsEvent] { events }
    func save(_ events: [QueuedAnalyticsEvent]) { self.events = events }
}

private final class SpyClient: AuthenticatedAPIClientProtocol, @unchecked Sendable {
    var postCount = 0
    var lastPath: String?
    var shouldFail = false
    /// Event count seen in each POST body, so batching can be asserted.
    var batchSizes: [Int] = []

    func get<Response: Decodable & Sendable>(_ path: String, query: [URLQueryItem]) async throws -> Response {
        throw URLError(.unsupportedURL)
    }

    func post<Body: Encodable & Sendable, Response: Decodable & Sendable>(
        _ path: String, body: Body
    ) async throws -> Response {
        postCount += 1
        lastPath = path
        if let data = try? JSONEncoder().encode(body),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let events = object["events"] as? [[String: Any]] {
            batchSizes.append(events.count)
        }
        if shouldFail { throw URLError(.notConnectedToInternet) }
        let payload = try JSONSerialization.data(
            withJSONObject: ["accepted": 1, "duplicates": 0, "rejected": 0]
        )
        return try JSONDecoder().decode(Response.self, from: payload)
    }

    func postEmpty<Response: Decodable & Sendable>(_ path: String) async throws -> Response {
        throw URLError(.unsupportedURL)
    }
    func patch<Body: Encodable & Sendable, Response: Decodable & Sendable>(
        _ path: String, body: Body
    ) async throws -> Response { throw URLError(.unsupportedURL) }
    func delete<Response: Decodable & Sendable>(_ path: String) async throws -> Response {
        throw URLError(.unsupportedURL)
    }
}

final class BackendAnalyticsRecorderTests: XCTestCase {
    private func makeRecorder(
        store: MemoryQueueStore,
        client: SpyClient,
        threshold: Int = 20,
        enabled: @escaping @Sendable () -> Bool = { true }
    ) -> BackendAnalyticsRecorder {
        BackendAnalyticsRecorder(
            store: store, client: client, appVersion: "1.2.3",
            batchThreshold: threshold, isEnabled: enabled
        )
    }

    /// The whole point of this recorder over GamificationEventRecorder: screen
    /// views must NOT each cost a network request.
    func testDoesNotPostBeforeReachingBatchThreshold() {
        let store = MemoryQueueStore(), client = SpyClient()
        let recorder = makeRecorder(store: store, client: client, threshold: 5)

        for i in 0..<4 { recorder.screenView("screen_\(i)") }

        XCTAssertEqual(client.postCount, 0)
        XCTAssertEqual(store.events.count, 4)
    }

    func testFlushSendsOneBatchAndClearsQueue() async {
        let store = MemoryQueueStore(), client = SpyClient()
        let recorder = makeRecorder(store: store, client: client)

        recorder.screenView("home")
        recorder.screenView("dua")
        await recorder.flush()

        XCTAssertEqual(client.postCount, 1, "both events should go in a single request")
        XCTAssertEqual(client.batchSizes, [2])
        XCTAssertEqual(client.lastPath, "v1/analytics/events")
        XCTAssertTrue(store.events.isEmpty)
    }

    /// A failed flush must not lose events — they're retried next time, and the
    /// ingest is idempotent per client_event_id so nothing double-counts.
    func testFailedFlushKeepsEventsQueued() async {
        let store = MemoryQueueStore(), client = SpyClient()
        client.shouldFail = true
        let recorder = makeRecorder(store: store, client: client)

        recorder.screenView("home")
        await recorder.flush()

        XCTAssertEqual(store.events.count, 1)
    }

    func testOptOutRecordsNothingAndFlushesNothing() async {
        let store = MemoryQueueStore(), client = SpyClient()
        let recorder = makeRecorder(store: store, client: client, enabled: { false })

        recorder.screenView("home")
        recorder.event("widget_opened_app", params: ["route": "dua"])
        await recorder.flush()

        XCTAssertTrue(store.events.isEmpty)
        XCTAssertEqual(client.postCount, 0)
    }

    /// Consent is re-read per call, so revoking it in Settings takes effect
    /// immediately rather than on next launch.
    func testConsentIsReReadPerCall() {
        let store = MemoryQueueStore(), client = SpyClient()
        let allowed = NSLock(); var isOn = true
        let recorder = makeRecorder(store: store, client: client, threshold: 99) {
            allowed.lock(); defer { allowed.unlock() }; return isOn
        }

        recorder.screenView("home")
        allowed.lock(); isOn = false; allowed.unlock()
        recorder.screenView("dua")

        XCTAssertEqual(store.events.count, 1, "the post-revocation event must not be queued")
    }

    func testDiscardQueuedEmptiesTheQueue() {
        let store = MemoryQueueStore(), client = SpyClient()
        let recorder = makeRecorder(store: store, client: client)
        recorder.screenView("home")

        recorder.discardQueued()

        XCTAssertTrue(store.events.isEmpty)
    }

    /// Only the error's type — never its message, which can embed user input.
    func testNonFatalReportsTypeOnly() {
        let store = MemoryQueueStore(), client = SpyClient()
        let recorder = makeRecorder(store: store, client: client)

        struct SecretError: Error { let query = "is this halal" }
        recorder.nonFatal(SecretError())

        let params = store.events.first?.params ?? [:]
        XCTAssertEqual(params[AnalyticsEvents.paramErrorType], "SecretError")
        XCTAssertFalse(params.values.contains { $0.contains("halal") })
    }

    /// An offline week must not grow an unbounded file or a giant first flush.
    func testQueueIsCappedDroppingOldest() {
        let store = MemoryQueueStore()
        let overflow = FileAnalyticsEventQueueStore.maxQueued + 10
        let events = (0..<overflow).map { QueuedAnalyticsEvent(name: "e\($0)") }

        // The cap lives in the file store, so exercise it directly.
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        let fileStore = FileAnalyticsEventQueueStore(directory: directory)
        fileStore.save(events)

        let loaded = fileStore.load()
        XCTAssertEqual(loaded.count, FileAnalyticsEventQueueStore.maxQueued)
        XCTAssertEqual(loaded.first?.name, "e10", "oldest events should be the ones dropped")
        XCTAssertTrue(store.events.isEmpty)
    }
}
