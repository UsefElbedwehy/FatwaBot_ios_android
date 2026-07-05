import Foundation
import Observation

/// State machine for the Tasbeeh screen (docs/features/tasbeeh.md). Pure over
/// injected haptics/store; the confirm-before-reset UX decision (only prompt
/// when count > 0) lives in the view, driven by `count`.
@MainActor
@Observable
public final class TasbeehViewModel {
    public private(set) var selectedPreset: DhikrPreset = .bundled[0]
    public var customText: String = ""
    public private(set) var count: Int = 0
    public private(set) var target: Int = 33
    public private(set) var history: [TasbeehHistoryEntry] = []
    /// True exactly on the tick that reaches `target`; consumed by the view
    /// for a one-shot haptic/visual cue, not held as persistent state.
    public private(set) var justReachedTarget = false

    private let haptics: HapticsProviding
    private let store: TasbeehHistoryStoring
    private let now: @Sendable () -> Date

    public init(
        haptics: HapticsProviding = NoopHaptics(),
        store: TasbeehHistoryStoring,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.haptics = haptics
        self.store = store
        self.now = now
        self.history = store.load()
    }

    public var displayText: String {
        selectedPreset.id == DhikrPreset.custom.id ? customText : selectedPreset.arabicText
    }

    public var stats: TasbeehStats { .from(history: history) }

    public func select(preset: DhikrPreset) {
        selectedPreset = preset
        performReset()
    }

    public func changeTarget(_ value: Int) {
        target = max(1, value)
    }

    /// Increments unconditionally — counting past target is allowed and does
    /// not reset or block (spec requirement).
    public func increment() {
        let previousCount = count
        count += 1
        if previousCount < target, count >= target {
            justReachedTarget = true
            haptics.targetReached()
        } else {
            justReachedTarget = false
            haptics.tick()
        }
    }

    /// Clears the one-shot "just reached target" flag after the view consumes it.
    public func acknowledgeTargetReached() {
        justReachedTarget = false
    }

    public func reset() {
        performReset()
    }

    /// Records the current count to history (actual count, not target) and
    /// starts a fresh set with the same preset/target.
    public func completeSet() {
        guard count > 0 else { return }
        let entry = TasbeehHistoryEntry(
            presetId: selectedPreset.id == DhikrPreset.custom.id ? nil : selectedPreset.id,
            customText: selectedPreset.id == DhikrPreset.custom.id ? customText : nil,
            target: target,
            actualCount: count,
            completedAt: now()
        )
        history.append(entry)
        store.save(history)
        performReset()
    }

    private func performReset() {
        count = 0
        justReachedTarget = false
    }
}
