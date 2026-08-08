import XCTest
@testable import CoreKit

final class WorshipInboxTests: XCTestCase {
    private var container: URL!

    override func setUpWithError() throws {
        container = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: container)
    }

    func testDepositThenPeekRoundTrips() {
        let inbox = WorshipInbox(appGroupContainer: container)
        let entry = WorshipInboxEntry(
            eventType: "prayer_completed", metadata: ["prayer": "fajr"]
        )
        XCTAssertTrue(inbox.deposit(entry))

        let peeked = inbox.peek()
        XCTAssertEqual(peeked.count, 1)
        XCTAssertEqual(peeked.first?.eventType, "prayer_completed")
        XCTAssertEqual(peeked.first?.metadata["prayer"], "fajr")
        XCTAssertEqual(peeked.first?.clientEventId, entry.clientEventId)
    }

    func testPeekOnAnUntouchedInboxIsEmptyNotAnError() {
        // The directory does not exist until the first deposit. Every launch
        // before the user has ever tapped a tile takes this path.
        XCTAssertTrue(WorshipInbox(appGroupContainer: container).peek().isEmpty)
    }

    func testConcurrentDepositsAllSurvive() {
        let inbox = WorshipInbox(appGroupContainer: container)
        // The reason for one-file-per-entry. Under a shared-array store these
        // interleave into lost updates, and what gets lost is a user's record of
        // an act of worship.
        DispatchQueue.concurrentPerform(iterations: 50) { i in
            inbox.deposit(
                WorshipInboxEntry(eventType: "prayer_completed", metadata: ["i": "\(i)"])
            )
        }
        XCTAssertEqual(inbox.peek().count, 50)
        XCTAssertEqual(Set(inbox.peek().compactMap { $0.metadata["i"] }).count, 50)
    }

    func testPeekIsChronologicalRatherThanDirectoryOrder() {
        let inbox = WorshipInbox(appGroupContainer: container)
        let now = Date()
        // Deposited newest-first so filesystem order cannot accidentally pass.
        for offset in [0.0, -300.0, -600.0] {
            inbox.deposit(
                WorshipInboxEntry(
                    eventType: "prayer_completed",
                    occurredAt: now.addingTimeInterval(offset)
                )
            )
        }
        let times = inbox.peek().map(\.occurredAt)
        XCTAssertEqual(times, times.sorted())
    }

    func testClearRemovesOnlyTheEntriesHandedBack() {
        let inbox = WorshipInbox(appGroupContainer: container)
        let uploaded = WorshipInboxEntry(eventType: "prayer_completed")
        let arrivedDuringUpload = WorshipInboxEntry(eventType: "azkar_completed")
        inbox.deposit(uploaded)
        inbox.deposit(arrivedDuringUpload)

        // The app uploads what it peeked, then clears exactly that. An entry the
        // widget deposited *while* the upload was in flight must survive — a
        // destructive drain would silently eat it.
        inbox.clear([uploaded])

        let remaining = inbox.peek()
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.clientEventId, arrivedDuringUpload.clientEventId)
    }

    func testClearingTwiceIsHarmless() {
        let inbox = WorshipInbox(appGroupContainer: container)
        let entry = WorshipInboxEntry(eventType: "prayer_completed")
        inbox.deposit(entry)
        inbox.clear([entry])
        inbox.clear([entry])
        XCTAssertTrue(inbox.peek().isEmpty)
    }

    func testRedepositingTheSameEntryDoesNotDuplicateIt() {
        let inbox = WorshipInbox(appGroupContainer: container)
        let entry = WorshipInboxEntry(eventType: "prayer_completed")
        inbox.deposit(entry)
        inbox.deposit(entry)
        // Same client event id, one file. Keeps a retried tap from counting twice.
        XCTAssertEqual(inbox.peek().count, 1)
    }

    func testACorruptFileDoesNotTakeTheWholeInboxDown() throws {
        let inbox = WorshipInbox(appGroupContainer: container)
        let good = WorshipInboxEntry(eventType: "prayer_completed")
        inbox.deposit(good)
        try Data("not json".utf8).write(
            to: container.appendingPathComponent("worship-inbox/broken.json")
        )
        // One unreadable file must not cost the user every other logged deed.
        let peeked = inbox.peek()
        XCTAssertEqual(peeked.count, 1)
        XCTAssertEqual(peeked.first?.clientEventId, good.clientEventId)
    }
}
