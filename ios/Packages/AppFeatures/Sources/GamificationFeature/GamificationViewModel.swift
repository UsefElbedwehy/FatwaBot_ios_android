import CoreKit
import Foundation
import NetworkingKit
import Observation

/// State machine for the Gamification screen (docs/features/gamification.md).
/// Renders server descriptors verbatim — no client-side scoring/streak math.
@MainActor
@Observable
public final class GamificationViewModel {
    public private(set) var profile: GamificationProfile = .empty
    public private(set) var isLoading = false
    public private(set) var error: String?

    private let client: AuthenticatedAPIClientProtocol
    private let recorder: GamificationEventRecorder?
    private let timezone: String
    private let widgetStore: GamificationWidgetSnapshotStore?
    private let reloadWidgets: (@Sendable () -> Void)?
    private let now: @Sendable () -> Date

    public init(
        client: AuthenticatedAPIClientProtocol,
        recorder: GamificationEventRecorder? = nil,
        timezone: String = TimeZone.current.identifier,
        widgetStore: GamificationWidgetSnapshotStore? = nil,
        reloadWidgets: (@Sendable () -> Void)? = nil,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.client = client
        self.recorder = recorder
        self.timezone = timezone
        self.widgetStore = widgetStore
        self.reloadWidgets = reloadWidgets
        self.now = now
    }

    public func load() async {
        isLoading = true
        error = nil
        // Flush any queued events first so a fresh profile reflects them.
        await recorder?.flush()
        do {
            profile = try await client.get(
                "v1/gamification/profile",
                query: [URLQueryItem(name: "timezone", value: timezone)]
            )
            writeWidgetSnapshot()
        } catch {
            self.error = error.userFacingMessage
        }
        isLoading = false
    }

    /// Widgets show one headline streak/mission, not the full profile — the
    /// longest current streak, and the first not-yet-complete daily mission
    /// (falling back to the first daily mission if all are complete).
    private func writeWidgetSnapshot() {
        guard let widgetStore else { return }
        let topStreak = profile.streaks.max { $0.currentLength < $1.currentLength }.map {
            GamificationWidgetSnapshot.Streak(
                name: $0.name, currentLength: $0.currentLength,
                longestLength: $0.longestLength, graceRemaining: $0.graceRemaining
            )
        }
        let dailyMissions = profile.missions.filter { $0.window == "daily" }
        let dailyChallenge = (dailyMissions.first { $0.progress < $0.target } ?? dailyMissions.first).map {
            GamificationWidgetSnapshot.DailyChallenge(name: $0.name, progress: $0.progress, target: $0.target)
        }
        widgetStore.write(GamificationWidgetSnapshot(topStreak: topStreak, dailyChallenge: dailyChallenge, generatedAt: now()))
        reloadWidgets?()
    }
}
