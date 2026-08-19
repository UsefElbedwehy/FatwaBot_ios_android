import Foundation

/// One worship action logged from outside the app — currently the interactive
/// متابعة العبادات widget.
public struct WorshipInboxEntry: Codable, Equatable, Sendable {
    /// Idempotency key. Generated at the tap, not at drain time, so a drain that
    /// is interrupted after upload but before deletion re-submits the *same* id
    /// and the server dedupes it rather than double-counting the deed.
    public let clientEventId: String
    public let eventType: String
    public let occurredAt: Date
    public let timezone: String
    public let metadata: [String: String]

    public init(
        clientEventId: String = UUID().uuidString,
        eventType: String,
        occurredAt: Date = Date(),
        timezone: String = TimeZone.current.identifier,
        metadata: [String: String] = [:]
    ) {
        self.clientEventId = clientEventId
        self.eventType = eventType
        self.occurredAt = occurredAt
        self.timezone = timezone
        self.metadata = metadata
    }
}

/// A drop-box in the app group that the widget writes to and the app drains.
///
/// ## Why not just append to the existing activity-event queue
/// `ActivityEventQueueStoring` persists the whole array through `save(_:)`. Two
/// processes doing read-modify-write on one file is a lost update, and the thing
/// lost is a user's record of an act of worship — the app would show a streak
/// broken on a day they had in fact prayed. That is not an acceptable failure
/// mode for a convenience feature.
///
/// ## Why one file per entry
/// Each deposit creates its own uniquely-named file, so there is **no shared
/// mutable state to race on**: the widget only ever creates, the app only ever
/// reads-then-deletes. An append to a shared file would still be a
/// read-modify-write under a different name. This costs an inode per tap and
/// buys a design where concurrent writers cannot corrupt or drop each other's
/// work — the right trade when the write rate is a handful of taps a day.
///
/// ## Ordering
/// `drain()` sorts by `occurredAt` rather than trusting directory order, which
/// is unspecified. Nothing downstream depends on ordering today, but a caller
/// reasonably assumes chronology and filesystem enumeration order is exactly the
/// kind of thing that behaves in testing and differs on device.
public struct WorshipInbox: Sendable {
    private let directory: URL

    public init(appGroupContainer: URL) {
        self.directory = appGroupContainer.appendingPathComponent("worship-inbox", isDirectory: true)
    }

    /// Records one action. Best-effort by design: a widget tap has no UI in
    /// which to report a filesystem failure, and throwing here would surface as
    /// the tile simply not responding.
    @discardableResult
    public func deposit(_ entry: WorshipInboxEntry) -> Bool {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(entry) else { return false }
        do {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true
            )
            // Named by the event id: a retried deposit of the same entry
            // overwrites rather than duplicating.
            let url = directory.appendingPathComponent("\(entry.clientEventId).json")
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    /// Everything deposited since the last drain, oldest first.
    ///
    /// Does **not** delete — see `clear(_:)`. Splitting read from delete is what
    /// lets the app hand entries to the upload path and only discard the ones it
    /// actually accepted; draining destructively would lose every entry in a
    /// batch whose upload failed.
    public func peek() -> [WorshipInboxEntry] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil
        )) ?? []
        return urls
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> WorshipInboxEntry? in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? decoder.decode(WorshipInboxEntry.self, from: data)
            }
            .sorted { $0.occurredAt < $1.occurredAt }
    }

    /// Discards the named entries. Unknown ids are ignored, so a double drain is
    /// harmless.
    public func clear(_ entries: [WorshipInboxEntry]) {
        for entry in entries {
            try? FileManager.default.removeItem(
                at: directory.appendingPathComponent("\(entry.clientEventId).json")
            )
        }
    }
}
