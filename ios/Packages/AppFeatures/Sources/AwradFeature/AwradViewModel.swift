import ContentKit
import CoreKit
import Foundation
import Observation

/// Daily-board state machine (docs/features/awrad.md). Pure over injected
/// store/clock; template loading from ContentKit is a thin wrapper kept
/// separate so board logic is unit-testable with hand-built fixtures.
@MainActor
@Observable
public final class AwradViewModel {
    public private(set) var templates: [WirdTemplate] = []
    public private(set) var wirds: [Wird] = []
    public private(set) var progress: [WirdDailyProgress] = []
    public private(set) var dayCompletions: [WirdDayCompletionRecord] = []

    private let contentService: ContentService?
    private let store: WirdStoring
    private let haptics: HapticsProviding
    private let activityEvents: ActivityEventRecording
    private let nameResolver: FixedWirdSlots.NameResolver
    private let now: @Sendable () -> Date
    private let calendar: Calendar

    public init(
        contentService: ContentService? = nil,
        store: WirdStoring,
        haptics: HapticsProviding = NoopHaptics(),
        activityEvents: ActivityEventRecording = NoopActivityEventRecording(),
        nameResolver: @escaping FixedWirdSlots.NameResolver = FixedWirdSlots.defaultNames,
        now: @escaping @Sendable () -> Date = { Date() },
        calendar: Calendar = .current
    ) {
        self.contentService = contentService
        self.store = store
        self.haptics = haptics
        self.activityEvents = activityEvents
        self.nameResolver = nameResolver
        self.now = now
        self.calendar = calendar
        self.wirds = []
        self.progress = store.loadProgress()
        self.dayCompletions = store.loadDayCompletions()
        reload()
    }

    /// Re-reads everything off the store. The view model is a singleton that
    /// outlives a backgrounding, and `WirdCompletionResponder` writes to the same
    /// files from a notification action while no UI is alive — without this the
    /// board would still show the wird as outstanding after the user answered
    /// "yes" from the lock screen.
    ///
    /// Also normalizes fixed-slot names to the current language on every call
    /// (`FixedWirdSlots.normalized`) — passive, not "أضف ورد اليوم": it fixes a
    /// name frozen under a language the user isn't in anymore, it never adds or
    /// reactivates a slot, so it needs no button and no confirmation.
    public func reload() {
        let loaded = store.loadWirds()
        let normalized = FixedWirdSlots.normalized(loaded, name: nameResolver)
        if normalized != loaded { store.saveWirds(normalized) }
        wirds = normalized
        progress = store.loadProgress()
        dayCompletions = store.loadDayCompletions()
    }

    public func loadTemplates(locale: String) async {
        guard let contentService else { return }
        templates = await contentService.wirdTemplates(locale: locale)?.templates ?? []
    }

    public var activeWirds: [Wird] { wirds.filter(\.isActive) }

    public var stats: WirdStats {
        .compute(wirds: wirds, progress: progress, dayCompletions: dayCompletions)
    }

    /// Today's tally for a wird (0 if untouched today).
    public func todayCount(for wirdId: String) -> Int {
        progress.first { $0.wirdId == wirdId && $0.dateKey == todayKey }?.count ?? 0
    }

    public var isDayCompletedToday: Bool {
        dayCompletions.contains { $0.dateKey == todayKey }
    }

    /// "أضف ورد اليوم" — seeds whichever of the four fixed slots
    /// (`FixedWirdSlot`) aren't already active on the board. A deliberate,
    /// one-tap action rather than something that happens on every launch (see
    /// `FixedWirdSlots.applied`'s doc comment for why that changed).
    public func addTodaysWird() {
        let updated = FixedWirdSlots.applied(to: wirds, name: nameResolver, now: now())
        guard updated != wirds else { return }
        wirds = updated
        store.saveWirds(wirds)
    }

    public func createWird(fromTemplate template: WirdTemplate) {
        appendWird(Wird(
            name: template.name, type: template.type, target: template.defaultTarget,
            unit: template.defaultUnit, frequency: template.defaultFrequency, createdAt: now()
        ))
    }

    public func createCustomWird(name: String, type: String, target: Int, unit: String, frequency: String) {
        appendWird(Wird(name: name, type: type, target: max(1, target), unit: unit, frequency: frequency, createdAt: now()))
    }

    private func appendWird(_ wird: Wird) {
        wirds.append(wird)
        store.saveWirds(wirds)
    }

    /// Increments unconditionally — ticking past target does not error.
    public func tick(wirdId: String, amount: Int = 1) {
        let key = todayKey
        let countBefore = todayCount(for: wirdId)
        if let index = progress.firstIndex(where: { $0.wirdId == wirdId && $0.dateKey == key }) {
            progress[index].count += amount
        } else {
            progress.append(WirdDailyProgress(wirdId: wirdId, dateKey: key, count: amount))
        }
        store.saveProgress(progress)
        let wird = wirds.first { $0.id == wirdId }
        let target = wird?.target ?? 0
        let justReachedTarget = countBefore < target && todayCount(for: wirdId) >= target
        if justReachedTarget {
            haptics.targetReached()
        } else {
            haptics.tick()
        }
        activityEvents.record(eventType: "wird_ticked", metadata: ["wird_id": wirdId])
        // Leaderboard currency (owner decision, 2026-07). The scoring engine
        // filters on event type alone — it cannot look inside metadata — so
        // "rank only the four fixed slots" needs its own event rather than a
        // filter over `wird_ticked`.
        //
        // Ranking on `wird_day_completed` instead would be unfair in both
        // directions: it is all-or-nothing over *every* active wird, so a user
        // with one trivial custom wird earns it more easily than a user with
        // ten. The fixed four are on every board by construction, which is what
        // makes them comparable between users at all.
        if justReachedTarget, wird?.isFixed == true {
            activityEvents.record(eventType: "fixed_wird_completed", metadata: ["wird_id": wirdId])
        }
    }

    /// Records today's completion only if every *active* wird has reached its
    /// target today; idempotent (repeated calls on an already-completed day
    /// are no-ops). Returns whether completion was recorded just now.
    @discardableResult
    public func markDayComplete() -> Bool {
        let key = todayKey
        guard !dayCompletions.contains(where: { $0.dateKey == key }) else { return false }
        let active = activeWirds
        guard !active.isEmpty, active.allSatisfy({ todayCount(for: $0.id) >= $0.target }) else { return false }
        let record = WirdDayCompletionRecord(dateKey: key, completedAt: now())
        dayCompletions.append(record)
        store.recordDayCompletion(record)
        haptics.targetReached()
        activityEvents.record(eventType: "wird_day_completed", metadata: [:])
        return true
    }

    /// Removes a wird from the active board — fixed or custom, no distinction
    /// anymore (client decision, 2026-08-12). Archives rather than erases, so
    /// historical progress/stats stay accurate and re-adding a fixed slot later
    /// via `addTodaysWird()` restores its history under the same id instead of
    /// starting a duplicate record.
    @discardableResult
    public func deleteWird(_ wirdId: String) -> Bool {
        guard let index = wirds.firstIndex(where: { $0.id == wirdId }) else { return false }
        wirds[index].archivedAt = now()
        store.saveWirds(wirds)
        return true
    }

    /// Retargeting is allowed for every wird, fixed ones included — "ورد يومي من
    /// القرآن" is a different number of pages for different people, and a slot the
    /// user cannot size to their own routine is a slot they will ignore.
    /// Renaming is not offered, for any wird, on either platform.
    public func setTarget(wirdId: String, target: Int) {
        guard let index = wirds.firstIndex(where: { $0.id == wirdId }) else { return }
        wirds[index].target = max(1, target)
        store.saveWirds(wirds)
    }

    private var todayKey: String { Self.dateKey(for: now(), calendar: calendar) }

    /// `nonisolated` because `WirdCompletionResponder` derives the same key off
    /// the main actor, from a notification action with no UI alive. It is pure
    /// over its arguments, so there is nothing for the actor to protect.
    nonisolated static func dateKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}
