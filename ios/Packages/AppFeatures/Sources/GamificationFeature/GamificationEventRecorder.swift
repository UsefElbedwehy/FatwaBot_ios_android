import CoreKit
import Foundation
import NetworkingKit

private struct SubmitEventsRequest: Encodable {
    struct Event: Encodable {
        let client_event_id: String
        let event_type: String
        let occurred_at: Date
        let timezone: String
        let metadata: [String: String]
    }
    let events: [Event]
}

// internal (not private) so tests can construct it via @testable import.
struct SubmitEventsResponse: Decodable {
    let accepted: Int
    let duplicates: Int
}

/// Concrete `ActivityEventRecording` (CoreKit) — the thing Tasbeeh/Azkar/
/// Awrad/Hadith are actually injected with. Queues locally first (so
/// `record` never blocks or fails visibly to the caller), then flushes
/// opportunistically; a failed flush just leaves events queued for next time.
///
/// Not internally synchronized, matching the existing local-store
/// convention (e.g. FileTasbeehHistoryStore) — every caller is a
/// `@MainActor` ViewModel, so calls are already serialized in practice.
public final class GamificationEventRecorder: ActivityEventRecording {
    private let store: ActivityEventQueueStoring
    private let client: AuthenticatedAPIClientProtocol

    public init(store: ActivityEventQueueStoring, client: AuthenticatedAPIClientProtocol) {
        self.store = store
        self.client = client
    }

    public func record(eventType: String, metadata: [String: String]) {
        var queue = store.load()
        queue.append(QueuedActivityEvent(eventType: eventType, metadata: metadata))
        store.save(queue)

        Task { [weak self] in
            await self?.flush()
        }
    }

    /// Submits every currently-queued event in one batch (the backend ingest
    /// is idempotent per client_event_id, so a partial-failure retry never
    /// double-counts). Clears the queue only after a confirmed round-trip.
    public func flush() async {
        let pending = store.load()
        guard !pending.isEmpty else { return }

        let request = SubmitEventsRequest(events: pending.map {
            .init(client_event_id: $0.clientEventId, event_type: $0.eventType, occurred_at: $0.occurredAt, timezone: $0.timezone, metadata: $0.metadata)
        })
        do {
            let _: SubmitEventsResponse = try await client.post("v1/gamification/events", body: request)
            // Only drop the events we actually just submitted — new ones may
            // have queued concurrently while this flush was in flight.
            let stillPending = store.load().filter { current in !pending.contains { $0.clientEventId == current.clientEventId } }
            store.save(stillPending)
        } catch {
            // Silent failure (docs/features/gamification.md): stays queued, retried on next record() or app launch.
        }
    }
}
