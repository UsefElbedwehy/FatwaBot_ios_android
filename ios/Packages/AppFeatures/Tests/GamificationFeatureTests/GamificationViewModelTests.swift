import XCTest
import CoreKit
import NetworkingKit
@testable import GamificationFeature

final class InMemoryActivityEventQueueStore: ActivityEventQueueStoring, @unchecked Sendable {
    var events: [QueuedActivityEvent] = []
    func load() -> [QueuedActivityEvent] { events }
    func save(_ events: [QueuedActivityEvent]) { self.events = events }
}

final class FakeAuthenticatedAPIClient: AuthenticatedAPIClientProtocol, @unchecked Sendable {
    var getHandler: (@Sendable (String, [URLQueryItem]) throws -> Any)?
    var postHandler: (@Sendable (String, Any) throws -> Any)?
    private(set) var postCallCount = 0

    func get<Response: Decodable & Sendable>(_ path: String, query: [URLQueryItem]) async throws -> Response {
        guard let result = try getHandler?(path, query) as? Response else {
            throw APIError.transport("no handler configured")
        }
        return result
    }

    func post<Body: Encodable & Sendable, Response: Decodable & Sendable>(_ path: String, body: Body) async throws -> Response {
        postCallCount += 1
        guard let result = try postHandler?(path, body) as? Response else {
            throw APIError.transport("no handler configured")
        }
        return result
    }

    func postEmpty<Response: Decodable & Sendable>(_ path: String) async throws -> Response {
        throw APIError.transport("not used in these tests")
    }

    func patch<Body: Encodable & Sendable, Response: Decodable & Sendable>(_ path: String, body: Body) async throws -> Response {
        throw APIError.transport("not used in these tests")
    }

    func delete<Response: Decodable & Sendable>(_ path: String) async throws -> Response {
        throw APIError.transport("not used in these tests")
    }
}

private struct EmptyResponse: Decodable {}

final class GamificationEventRecorderTests: XCTestCase {
    func testRecordQueuesLocallyEvenBeforeAnyFlush() {
        let store = InMemoryActivityEventQueueStore()
        let client = FakeAuthenticatedAPIClient()
        client.postHandler = { _, _ in throw APIError.transport("offline") }
        let recorder = GamificationEventRecorder(store: store, client: client)

        recorder.record(eventType: "azkar_completed", metadata: ["category": "morning"])

        XCTAssertEqual(store.events.count, 1)
        XCTAssertEqual(store.events[0].eventType, "azkar_completed")
        XCTAssertEqual(store.events[0].metadata["category"], "morning")
    }

    func testFlushClearsQueueOnSuccessfulSubmit() async {
        let store = InMemoryActivityEventQueueStore()
        store.events = [QueuedActivityEvent(eventType: "tasbeeh_session_completed")]
        let client = FakeAuthenticatedAPIClient()
        client.postHandler = { _, _ in SubmitEventsResponse(accepted: 1, duplicates: 0) }
        let recorder = GamificationEventRecorder(store: store, client: client)

        await recorder.flush()

        XCTAssertEqual(store.events.count, 0)
    }

    func testFlushLeavesQueueIntactOnNetworkFailure() async {
        let store = InMemoryActivityEventQueueStore()
        store.events = [QueuedActivityEvent(eventType: "wird_ticked")]
        let client = FakeAuthenticatedAPIClient()
        client.postHandler = { _, _ in throw APIError.transport("offline") }
        let recorder = GamificationEventRecorder(store: store, client: client)

        await recorder.flush()

        XCTAssertEqual(store.events.count, 1, "a failed flush must not drop queued events")
    }

    func testFlushOnEmptyQueueDoesNotCallTheNetwork() async {
        let store = InMemoryActivityEventQueueStore()
        let client = FakeAuthenticatedAPIClient()
        client.postHandler = { _, _ in XCTFail("should not be called"); throw APIError.transport("x") }
        let recorder = GamificationEventRecorder(store: store, client: client)

        await recorder.flush()
    }
}

@MainActor
final class GamificationViewModelTests: XCTestCase {
    func testLoadPopulatesProfileFromServer() async {
        let client = FakeAuthenticatedAPIClient()
        client.getHandler = { path, _ in
            XCTAssertEqual(path, "v1/gamification/profile")
            return GamificationProfile(
                streaks: [GamificationStreak(key: "azkar_streak", name: "Azkar Streak", currentLength: 3, longestLength: 5, graceRemaining: 1)],
                missions: [GamificationMission(key: "m1", name: "Weekly Tasbeeh", progress: 2, target: 3, window: "weekly", endsAt: nil)],
                badges: [GamificationBadge(key: "b1", name: "First Azkar", iconRef: "badge", earnedAt: Date())]
            )
        }
        let viewModel = GamificationViewModel(client: client)

        await viewModel.load()

        XCTAssertEqual(viewModel.profile.streaks.count, 1)
        XCTAssertEqual(viewModel.profile.streaks[0].currentLength, 3)
        XCTAssertEqual(viewModel.profile.missions[0].progress, 2)
        XCTAssertTrue(viewModel.profile.badges[0].isEarned)
        XCTAssertNil(viewModel.error)
        XCTAssertFalse(viewModel.isLoading)
    }

    func testLoadSurfacesErrorAndLeavesProfileEmpty() async {
        let client = FakeAuthenticatedAPIClient()
        client.getHandler = { _, _ in throw APIError.server(statusCode: 401, code: "unauthorized") }
        let viewModel = GamificationViewModel(client: client)

        await viewModel.load()

        XCTAssertNotNil(viewModel.error)
        XCTAssertEqual(viewModel.profile, .empty)
    }

    func testLoadFlushesQueuedEventsFirst() async {
        let store = InMemoryActivityEventQueueStore()
        store.events = [QueuedActivityEvent(eventType: "azkar_completed")]
        let flushClient = FakeAuthenticatedAPIClient()
        flushClient.postHandler = { _, _ in SubmitEventsResponse(accepted: 1, duplicates: 0) }
        let recorder = GamificationEventRecorder(store: store, client: flushClient)

        let profileClient = FakeAuthenticatedAPIClient()
        profileClient.getHandler = { _, _ in GamificationProfile.empty }
        let viewModel = GamificationViewModel(client: profileClient, recorder: recorder)

        await viewModel.load()

        XCTAssertEqual(store.events.count, 0, "load() should flush the queue before fetching the profile")
    }

    func testLoadWritesWidgetSnapshotWithLongestStreakAndFirstIncompleteDailyMission() async {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let widgetStore = GamificationWidgetSnapshotStore(appGroupContainer: tempDir)
        let client = FakeAuthenticatedAPIClient()
        client.getHandler = { _, _ in
            GamificationProfile(
                streaks: [
                    GamificationStreak(key: "azkar", name: "Azkar", currentLength: 3, longestLength: 10, graceRemaining: 0),
                    GamificationStreak(key: "fajr", name: "Fajr", currentLength: 7, longestLength: 7, graceRemaining: 1),
                ],
                missions: [
                    GamificationMission(key: "m1", name: "Done Today", progress: 3, target: 3, window: "daily", endsAt: nil),
                    GamificationMission(key: "m2", name: "In Progress", progress: 1, target: 3, window: "daily", endsAt: nil),
                    GamificationMission(key: "m3", name: "Weekly Thing", progress: 1, target: 3, window: "weekly", endsAt: nil),
                ],
                badges: []
            )
        }
        let viewModel = GamificationViewModel(client: client, widgetStore: widgetStore)

        await viewModel.load()

        let snapshot = widgetStore.read()
        XCTAssertEqual(snapshot?.topStreak?.name, "Fajr", "the longest current streak, not the first one")
        XCTAssertEqual(snapshot?.dailyChallenge?.name, "In Progress", "the first not-yet-complete daily mission, ignoring weekly missions")
    }

    func testLoadDoesNotWriteWidgetSnapshotWhenRequestFails() async {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let widgetStore = GamificationWidgetSnapshotStore(appGroupContainer: tempDir)
        let client = FakeAuthenticatedAPIClient()
        client.getHandler = { _, _ in throw APIError.server(statusCode: 500, code: nil) }
        let viewModel = GamificationViewModel(client: client, widgetStore: widgetStore)

        await viewModel.load()

        XCTAssertNil(widgetStore.read())
    }
}
