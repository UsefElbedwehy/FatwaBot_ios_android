import CoreKit
import Observation

/// State machine for the 4-screen value-first onboarding flow
/// (docs/features/onboarding.md). Permission requests are injected as plain
/// closures rather than depending on PrayerFeature's LocationProviding /
/// PrayerNotificationScheduling directly — ADR-0010 forbids feature -> feature
/// dependencies, so the App composition root wires these to the real
/// M1 permission-request code paths; this package never touches CoreLocation
/// or UNUserNotificationCenter itself.
public enum OnboardingStep: Int, CaseIterable, Sendable {
    case welcome
    case highlights
    case locationPriming
    case notificationPriming
}

@MainActor
@Observable
public final class OnboardingViewModel {
    public private(set) var step: OnboardingStep = .welcome

    private let requestLocation: @Sendable () async -> Void
    private let requestNotifications: @Sendable () async -> Void
    private let completionStore: OnboardingCompletionStore
    private let onFinished: @Sendable () -> Void

    public init(
        requestLocation: @escaping @Sendable () async -> Void,
        requestNotifications: @escaping @Sendable () async -> Void,
        completionStore: OnboardingCompletionStore,
        onFinished: @escaping @Sendable () -> Void
    ) {
        self.requestLocation = requestLocation
        self.requestNotifications = requestNotifications
        self.completionStore = completionStore
        self.onFinished = onFinished
    }

    public func advance() {
        guard let next = OnboardingStep(rawValue: step.rawValue + 1) else {
            finish()
            return
        }
        step = next
    }

    /// "Allow" on the location-priming screen: triggers the real OS prompt,
    /// then advances regardless of the outcome — denial still reaches Home
    /// via the existing manual-city fallback (docs/features/prayer.md).
    public func allowLocation() async {
        await requestLocation()
        advance()
    }

    /// "Allow" on the notification-priming screen: triggers the real OS
    /// prompt, then finishes onboarding regardless of outcome.
    public func allowNotifications() async {
        await requestNotifications()
        finish()
    }

    /// "Not now" / "Skip" on any screen — never calls the permission API,
    /// just sequences forward (or finishes, from the last screen).
    public func skip() {
        advance()
    }

    private func finish() {
        completionStore.markCompleted()
        onFinished()
    }
}
