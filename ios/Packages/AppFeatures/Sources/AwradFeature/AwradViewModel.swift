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
    private let activityEvents: ActivityEventRecording
    private let now: @Sendable () -> Date
    private let calendar: Calendar

    public init(
        contentService: ContentService? = nil,
        store: WirdStoring,
        activityEvents: ActivityEventRecording = NoopActivityEventRecording(),
        now: @escaping @Sendable () -> Date = { Date() },
        calendar: Calendar = .current
    ) {
        self.contentService = contentService
        self.store = store
        self.activityEvents = activityEvents
        self.now = now
        self.calendar = calendar
        self.wirds = store.loadWirds()
        self.progress = store.loadProgress()
        self.dayCompletions = store.loadDayCompletions()
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
        if let index = progress.firstIndex(where: { $0.wirdId == wirdId && $0.dateKey == key }) {
            progress[index].count += amount
        } else {
            progress.append(WirdDailyProgress(wirdId: wirdId, dateKey: key, count: amount))
        }
        store.saveProgress(progress)
        activityEvents.record(eventType: "wird_ticked", metadata: ["wird_id": wirdId])
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
        activityEvents.record(eventType: "wird_day_completed", metadata: [:])
        return true
    }

    /// Archives without deleting historical progress — stats remain accurate.
    public func archiveWird(_ wirdId: String) {
        guard let index = wirds.firstIndex(where: { $0.id == wirdId }) else { return }
        wirds[index].archivedAt = now()
        store.saveWirds(wirds)
    }

    private var todayKey: String { Self.dateKey(for: now(), calendar: calendar) }

    static func dateKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}
