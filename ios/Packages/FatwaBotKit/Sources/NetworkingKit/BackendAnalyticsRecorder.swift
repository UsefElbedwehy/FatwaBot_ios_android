import CoreKit
import Foundation

private struct SubmitAnalyticsRequest: Encodable {
    struct Event: Encodable {
        let client_event_id: String
        let name: String
        let occurred_at: Date
        let platform: String
        let app_version: String
        let params: [String: String]
    }
    let events: [Event]
}

// internal (not private) so tests can construct it via @testable import.
struct SubmitAnalyticsResponse: Decodable {
    let accepted: Int
    let duplicates: Int
    let rejected: Int
}

/// `AnalyticsTracking` backed by our OWN ingest (`POST /v1/analytics/events`)
/// instead of a third-party SDK — see
/// docs/features/analytics-and-crash-reporting.md for why.
///
/// Unlike `GamificationEventRecorder`, which flushes on every `record` because
/// each event matters individually, this **batches**: screen views are frequent
/// and individually worthless, so posting one request per screen change would
/// burn battery and radio for nothing. Events accumulate on disk and go out in
/// one request once `batchThreshold` is reached, or when the app backgrounds /
/// launches (`flush()`).
///
/// Not internally synchronized, matching the existing local-store convention
/// (see `GamificationEventRecorder`) — every caller is `@MainActor`, so calls
/// are already serialized in practice.
public final class BackendAnalyticsRecorder: AnalyticsTracking, @unchecked Sendable {
    private let store: AnalyticsEventQueueStoring
    private let client: AuthenticatedAPIClientProtocol
    private let platform: String
    private let appVersion: String
    private let batchThreshold: Int
    /// Read fresh on every call, so revoking consent in Settings takes effect
    /// immediately rather than on next launch.
    private let isEnabled: @Sendable () -> Bool

    public init(
        store: AnalyticsEventQueueStoring,
        client: AuthenticatedAPIClientProtocol,
        platform: String = "ios",
        appVersion: String,
        batchThreshold: Int = 20,
        isEnabled: @escaping @Sendable () -> Bool
    ) {
        self.store = store
        self.client = client
        self.platform = platform
        self.appVersion = appVersion
        self.batchThreshold = batchThreshold
        self.isEnabled = isEnabled
    }

    // MARK: - AnalyticsTracking

    public func screenView(_ screen: String) {
        event(AnalyticsEvents.screenView, params: [AnalyticsEvents.paramScreen: screen])
    }

    public func event(_ name: String, params: [String: String]) {
        guard isEnabled() else { return }
        var queue = store.load()
        queue.append(QueuedAnalyticsEvent(name: name, params: params))
        store.save(queue)
        if queue.count >= batchThreshold {
            Task { [weak self] in await self?.flush() }
        }
    }

    /// Only the error's *type* is reported. An error's `localizedDescription` can
    /// embed a URL, a file path or user input, and this pipeline must not carry
    /// free text.
    public func nonFatal(_ error: Error) {
        event(
            AnalyticsEvents.nonFatalError,
            params: [AnalyticsEvents.paramErrorType: String(describing: type(of: error))]
        )
    }

    // MARK: - Flushing

    /// Sends everything currently queued in one batch. Call on launch and when
    /// the app backgrounds. A failed flush leaves the queue intact for next time;
    /// the ingest is idempotent per `client_event_id`, so a retry after a
    /// partially-applied request never double-counts.
    public func flush() async {
        guard isEnabled() else { return }
        let pending = store.load()
        guard !pending.isEmpty else { return }

        let request = SubmitAnalyticsRequest(events: pending.map {
            .init(
                client_event_id: $0.clientEventId,
                name: $0.name,
                occurred_at: $0.occurredAt,
                platform: platform,
                app_version: appVersion,
                params: $0.params
            )
        })
        do {
            let _: SubmitAnalyticsResponse = try await client.post("v1/analytics/events", body: request)
            // Drop only what we just submitted — more may have queued while this
            // flush was in flight.
            let submitted = Set(pending.map(\.clientEventId))
            store.save(store.load().filter { !submitted.contains($0.clientEventId) })
        } catch {
            // Silent by design: analytics must never surface an error to the
            // user or block anything. Stays queued for the next attempt.
        }
    }

    /// Drops anything not yet sent. Called when the user opts out, so queued
    /// events from before the decision are never transmitted afterwards.
    public func discardQueued() {
        store.save([])
    }
}
