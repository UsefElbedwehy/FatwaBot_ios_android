import ContentKit
import CoreKit
import Foundation
import Observation

/// Session state machine for the Azkar reading experience (docs/features/azkar.md).
/// Pure over injected haptics/store/clock; category/item loading from
/// ContentKit is a thin wrapper (`loadCategories`) kept separate so the
/// session logic itself is unit-testable with hand-built fixtures.
@MainActor
@Observable
public final class AzkarViewModel {
    public private(set) var categories: [AzkarCategory] = []
    public private(set) var items: [AzkarItem] = []
    public private(set) var categoryId: String?
    public private(set) var currentItemIndex = 0
    public private(set) var currentItemCount = 0
    public private(set) var isSessionComplete = false
    public private(set) var completedCategoryIdsToday: Set<String>

    private let contentService: ContentService?
    private let haptics: HapticsProviding
    private let store: AzkarStoring
    private let activityEvents: ActivityEventRecording
    private let calendar: Calendar
    private let now: @Sendable () -> Date

    public init(
        contentService: ContentService? = nil,
        haptics: HapticsProviding = NoopHaptics(),
        store: AzkarStoring,
        activityEvents: ActivityEventRecording = NoopActivityEventRecording(),
        calendar: Calendar = .current,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.contentService = contentService
        self.haptics = haptics
        self.store = store
        self.activityEvents = activityEvents
        self.calendar = calendar
        self.now = now
        let today = now()
        self.completedCategoryIdsToday = Set(
            store.loadCompletions()
                .filter { calendar.isDate($0.completedAt, inSameDayAs: today) }
                .map(\.categoryId)
        )
    }

    public var currentItem: AzkarItem? {
        guard currentItemIndex < items.count else { return nil }
        return items[currentItemIndex]
    }

    public var progress: Double {
        guard !items.isEmpty else { return 0 }
        return Double(currentItemIndex) / Double(items.count)
    }

    public func loadCategories(locale: String) async {
        guard let contentService else { return }
        categories = await contentService.azkar(locale: locale)?.categories ?? []
    }

    public func isCompletedToday(_ categoryId: String) -> Bool {
        completedCategoryIdsToday.contains(categoryId)
    }

    /// Starts a session, resuming from a persisted same-day position for the
    /// same category if one exists (spec requirement).
    public func startSession(categoryId: String, items: [AzkarItem]) {
        self.categoryId = categoryId
        self.items = items
        isSessionComplete = false

        if let persisted = store.loadSession(),
           persisted.categoryId == categoryId,
           calendar.isDate(persisted.lastTouchedAt, inSameDayAs: now()),
           persisted.currentItemIndex < items.count {
            currentItemIndex = persisted.currentItemIndex
            currentItemCount = persisted.currentItemCount
        } else {
            currentItemIndex = 0
            currentItemCount = 0
            persistState()
        }
    }

    /// Increments the current item's count; auto-advances at exactly its
    /// repeatCount (never N+1). A no-op once the session is complete —
    /// makes completion idempotent.
    public func tick() {
        guard !isSessionComplete, let item = currentItem else { return }
        currentItemCount += 1
        if currentItemCount >= item.repeatCount {
            haptics.targetReached()
            advance()
        } else {
            haptics.tick()
            persistState()
        }
    }

    private func advance() {
        currentItemIndex += 1
        currentItemCount = 0
        if currentItemIndex >= items.count {
            completeSession()
        } else {
            persistState()
        }
    }

    private func completeSession() {
        guard let categoryId else { return }
        isSessionComplete = true
        store.saveSession(nil)
        store.recordCompletion(AzkarCompletionRecord(categoryId: categoryId, completedAt: now()))
        completedCategoryIdsToday.insert(categoryId)
        activityEvents.record(eventType: "azkar_completed", metadata: ["category_id": categoryId])
    }

    private func persistState() {
        guard let categoryId else { return }
        store.saveSession(AzkarSessionState(
            categoryId: categoryId,
            currentItemIndex: currentItemIndex,
            currentItemCount: currentItemCount,
            lastTouchedAt: now()
        ))
    }
}
