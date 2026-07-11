import Foundation
import PrayerKit

/// Boundary PrayerViewModel is injected with (ADR-0016) — keeps ActivityKit
/// (unavailable outside iOS/Catalyst) out of the ViewModel's compile
/// requirements and out of unit tests, mirroring HeadingProviding's
/// `#if canImport` seam in QiblaScreen.
public protocol PrayerLiveActivityManaging: Sendable {
    func start(locationName: String, prayerName: PrayerName, prayerTime: Date) async
    func update(prayerName: PrayerName, prayerTime: Date) async
    func end() async
}

public struct NoopPrayerLiveActivityManager: PrayerLiveActivityManaging {
    public init() {}
    public func start(locationName: String, prayerName: PrayerName, prayerTime: Date) async {}
    public func update(prayerName: PrayerName, prayerTime: Date) async {}
    public func end() async {}
}

#if canImport(ActivityKit) && os(iOS)
import ActivityKit

/// One Live Activity at a time — a fresh `start()` call while one is already
/// running just updates it rather than requesting a duplicate.
public final class SystemPrayerLiveActivityManager: PrayerLiveActivityManaging, @unchecked Sendable {
    /// Grace window after the countdown target passes before the system may
    /// consider the activity stale (ADR-0016 point 4).
    private static let staleGrace: TimeInterval = 30 * 60

    private var activity: Activity<PrayerActivityAttributes>?

    public init() {}

    public func start(locationName: String, prayerName: PrayerName, prayerTime: Date) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        if activity != nil {
            await update(prayerName: prayerName, prayerTime: prayerTime)
            return
        }
        let attributes = PrayerActivityAttributes(locationName: locationName)
        let state = PrayerActivityAttributes.ContentState(prayerName: prayerName.rawValue, prayerTime: prayerTime)
        let content = ActivityContent(state: state, staleDate: prayerTime.addingTimeInterval(Self.staleGrace))
        activity = try? Activity.request(attributes: attributes, content: content)
    }

    public func update(prayerName: PrayerName, prayerTime: Date) async {
        guard let activity else { return }
        let state = PrayerActivityAttributes.ContentState(prayerName: prayerName.rawValue, prayerTime: prayerTime)
        let content = ActivityContent(state: state, staleDate: prayerTime.addingTimeInterval(Self.staleGrace))
        await activity.update(content)
    }

    public func end() async {
        guard let activity else { return }
        await activity.end(nil, dismissalPolicy: .immediate)
        self.activity = nil
    }
}
#endif
