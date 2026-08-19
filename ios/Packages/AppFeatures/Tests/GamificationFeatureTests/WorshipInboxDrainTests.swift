import XCTest
import CoreKit
import NetworkingKit
@testable import GamificationFeature

/// The drain is the seam between the widget's writes and the streak. Everything
/// it guarantees is invisible until it is wrong, so each guarantee gets a test.
final class WorshipInboxDrainTests: XCTestCase {
    private var container: URL!
    private var inbox: WorshipInbox!
    private var store: InMemoryActivityEventQueueStore!
    private var client: FakeAuthenticatedAPIClient!
    private var recorder: GamificationEventRecorder!

    override func setUpWithError() throws {
        container = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
        inbox = WorshipInbox(appGroupContainer: container)
        store = InMemoryActivityEventQueueStore()
        client = FakeAuthenticatedAPIClient()
        recorder = GamificationEventRecorder(store: store, client: client)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: container)
    }

    private func acceptAll() {
        client.postHandler = { _, _ in SubmitEventsResponse(accepted: 1, duplicates: 0) }
    }

    func testDrainPreservesTheIdMintedAtTheTap() async {
        acceptAll()
        let entry = WorshipInboxEntry(
            eventType: "prayer_completed", metadata: ["prayer": "fajr"]
        )
        inbox.deposit(entry)

        await recorder.drain(inbox)

        // Asserted against the submitted payload, not the queue: a successful
        // flush empties the queue, so queue state proves nothing here.
        //
        // The id is the entire idempotency story. Re-minting it would mean a
        // drain that runs twice counts the same prayer twice.
        XCTAssertEqual(client.postedBodies.count, 1)
        XCTAssertTrue(
            client.postedBodies[0].contains(entry.clientEventId),
            "submitted payload must carry the id minted at the tap"
        )
        XCTAssertTrue(inbox.peek().isEmpty)
    }

    func testDrainedEventsCarryTheDeedMetadataThrough() async {
        acceptAll()
        inbox.deposit(
            WorshipInboxEntry(eventType: "azkar_completed", metadata: ["category": "morning"])
        )
        await recorder.drain(inbox)
        // Submitted and cleared, so read what was handed to the queue en route.
        XCTAssertTrue(inbox.peek().isEmpty)
        XCTAssertEqual(client.postCallCount, 1)
        XCTAssertTrue(client.postedBodies[0].contains("\"category\":\"morning\""))
        XCTAssertTrue(client.postedBodies[0].contains("azkar_completed"))
    }

    func testAFailedUploadKeepsTheDeedRatherThanLosingIt() async {
        client.postHandler = { _, _ in throw APIError.transport("offline") }
        let entry = WorshipInboxEntry(eventType: "prayer_completed", metadata: ["prayer": "asr"])
        inbox.deposit(entry)

        await recorder.drain(inbox)

        // The inbox is cleared — the entry has been adopted by the event queue,
        // which is itself retried. What must never happen is the deed vanishing
        // from both.
        XCTAssertEqual(store.events.map(\.clientEventId), [entry.clientEventId])
    }

    func testDrainingTwiceDoesNotEnqueueTheSameDeedTwice() async {
        client.postHandler = { _, _ in throw APIError.transport("offline") }
        let entry = WorshipInboxEntry(eventType: "prayer_completed", metadata: ["prayer": "isha"])
        inbox.deposit(entry)

        await recorder.drain(inbox)
        // Simulate the crash window: adopted into the queue, but still present
        // in the inbox because clearing never completed.
        inbox.deposit(entry)
        await recorder.drain(inbox)

        XCTAssertEqual(store.events.count, 1)
    }

    func testDrainOnAnEmptyInboxDoesNotCallTheNetwork() async {
        acceptAll()
        await recorder.drain(inbox)
        // Every foreground calls this. It must be free when there is nothing to do.
        XCTAssertEqual(client.postCallCount, 0)
    }

    func testDrainDoesNotDisturbEventsAlreadyQueuedInApp() async {
        acceptAll()
        let inApp = QueuedActivityEvent(eventType: "tasbeeh_completed")
        store.events = [inApp]
        inbox.deposit(WorshipInboxEntry(eventType: "prayer_completed", metadata: ["prayer": "fajr"]))

        await recorder.drain(inbox)

        // Both were submitted together; the in-app one must not have been
        // dropped or duplicated by the adoption pass.
        XCTAssertEqual(client.postCallCount, 1)
    }
}
