import ContentKit
import Foundation
import Observation

/// Last content-sync result, surfaced in Settings.
///
/// `syncAll` has reported failures honestly since the refresh methods stopped
/// swallowing them, but the app discarded the summary — so a broken sync was
/// diagnosable from a log and invisible to everyone else. That is most of the
/// distance between "we could have found this" and "we would have".
///
/// Deliberately not an alert or a banner. A failed sync is not an error the
/// user caused or can act on mid-session: the app is offline-first and keeps
/// working from cache. It belongs where someone looks when something seems
/// stale, next to the other diagnostics.
@MainActor
@Observable
final class ContentSyncStatus {
    enum State: Equatable {
        case never
        case syncing
        case succeeded(at: Date, updated: [String])
        case failed(at: Date, keys: [String])
    }

    private(set) var state: State = .never

    func beginSync() {
        // A retry must not leave the previous verdict on screen while it runs.
        state = .syncing
    }

    func finish(_ summary: ContentService.SyncSummary, now: Date = Date()) {
        state = summary.hasFailures
            ? .failed(at: now, keys: summary.failed)
            : .succeeded(at: now, updated: summary.updated)
    }
}
