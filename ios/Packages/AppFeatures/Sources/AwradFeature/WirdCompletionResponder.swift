import CoreKit
import Foundation

/// What a "yes, I did it" answer actually changed. Returned rather than logged
/// so the caller (and the tests) can assert on it.
public struct WirdCompletionOutcome: Equatable, Sendable {
    /// False when the id names a wird that no longer exists or has been archived.
    public let wirdFound: Bool
    /// True only when the answer actually moved today's count.
    public let ticked: Bool
    /// True only when *this* answer was the one that completed the day.
    public let dayCompleted: Bool

    public static let unknownWird = WirdCompletionOutcome(wirdFound: false, ticked: false, dayCompleted: false)

    public init(wirdFound: Bool, ticked: Bool, dayCompleted: Bool) {
        self.wirdFound = wirdFound
        self.ticked = ticked
        self.dayCompleted = dayCompleted
    }
}

/// Applies a "yes, I completed this wird" answer straight to the store, with no
/// `AwradViewModel` in the picture.
///
/// ## Why this type exists
/// The answer arrives from a notification action, which is delivered while the
/// app is backgrounded or not running at all. There is no live view model to
/// mutate, so the mutation has to go through `WirdStoring` directly — and
/// because it is the *same* state the UI writes, it has to reproduce the UI's
/// rules exactly rather than approximate them.
///
/// ## The rule it must not break
/// A *day* is complete only when every active wird has reached its target
/// (`AwradViewModel.markDayComplete`). Writing a `WirdDayCompletionRecord`
/// straight from a notification would report days complete whose per-wird counts
/// don't support it, inflating `completedDaysCount` and the Journey streaks. So
/// this raises the answered wird's count to its target — exactly the state a
/// user reaches by tapping it in the UI — and then lets day completion fall out
/// of the same all-active-wirds check.
///
/// ## Idempotency
/// The answer *sets* today's count to the target rather than incrementing by
/// one: re-answering a wird already at (or past) its target is detected by
/// `current < target` and short-circuits, so no progress is written and no
/// `wird_ticked` is recorded. A double-tap, a second notification for the same
/// wird, or answering after finishing in-app all collapse to a single effect.
/// Day completion is separately guarded by the one-record-per-`dateKey` check.
public struct WirdCompletionResponder: Sendable {
    private let store: WirdStoring
    private let activityEvents: ActivityEventRecording
    private let now: @Sendable () -> Date
    private let calendar: Calendar

    public init(
        store: WirdStoring,
        activityEvents: ActivityEventRecording = NoopActivityEventRecording(),
        now: @escaping @Sendable () -> Date = { Date() },
        calendar: Calendar = .current
    ) {
        self.store = store
        self.activityEvents = activityEvents
        self.now = now
        self.calendar = calendar
    }

    /// Answers "yes" for one wird. A deleted or archived id is a no-op, not a
    /// crash — a stale notification can outlive the wird it was scheduled for.
    @discardableResult
    public func answerCompleted(wirdId: String) -> WirdCompletionOutcome {
        let wirds = store.loadWirds()
        guard let wird = wirds.first(where: { $0.id == wirdId }), wird.isActive else {
            return .unknownWird
        }

        let key = AwradViewModel.dateKey(for: now(), calendar: calendar)
        var progress = store.loadProgress()
        let current = progress.first { $0.wirdId == wirdId && $0.dateKey == key }?.count ?? 0

        var ticked = false
        if current < wird.target {
            if let index = progress.firstIndex(where: { $0.wirdId == wirdId && $0.dateKey == key }) {
                progress[index].count = wird.target
            } else {
                progress.append(WirdDailyProgress(wirdId: wirdId, dateKey: key, count: wird.target))
            }
            store.saveProgress(progress)
            ticked = true
            // The same single event the in-app path fires: `tick(amount:)` records
            // one `wird_ticked` per call whatever the amount, so a one-shot jump to
            // target and a stepper drag are indistinguishable to gamification.
            activityEvents.record(eventType: "wird_ticked", metadata: ["wird_id": wirdId])
        }

        return WirdCompletionOutcome(
            wirdFound: true,
            ticked: ticked,
            dayCompleted: recordDayCompletionIfEarned(wirds: wirds, progress: progress, key: key)
        )
    }

    /// Byte-for-byte the `markDayComplete` rule, read off the store instead of
    /// off in-memory state.
    private func recordDayCompletionIfEarned(
        wirds: [Wird], progress: [WirdDailyProgress], key: String
    ) -> Bool {
        guard !store.loadDayCompletions().contains(where: { $0.dateKey == key }) else { return false }
        let active = wirds.filter(\.isActive)
        let counts = Dictionary(
            progress.filter { $0.dateKey == key }.map { ($0.wirdId, $0.count) },
            uniquingKeysWith: { first, _ in first }
        )
        guard !active.isEmpty, active.allSatisfy({ (counts[$0.id] ?? 0) >= $0.target }) else { return false }

        let record = WirdDayCompletionRecord(dateKey: key, completedAt: now())
        store.recordDayCompletion(record)
        activityEvents.record(eventType: "wird_day_completed", metadata: [:])
        return true
    }
}
