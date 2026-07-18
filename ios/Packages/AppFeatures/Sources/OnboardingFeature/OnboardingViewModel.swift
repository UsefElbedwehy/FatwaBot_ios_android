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
    /// Last on purpose — accounts are optional and must never gate the app
    /// (docs/features/accounts.md); the user has already seen the value.
    case signIn
}

/// A sign-in provider offered during onboarding. Kept as a plain value type so
/// OnboardingFeature doesn't depend on NetworkingKit (ADR-0010) — the App
/// composition root maps `id` back to an `AccountProvider`.
public struct OnboardingSignInOption: Identifiable, Sendable, Equatable {
    public let id: String
    public let titleKey: String
    public let systemImage: String

    public init(id: String, titleKey: String, systemImage: String) {
        self.id = id
        self.titleKey = titleKey
        self.systemImage = systemImage
    }
}

@MainActor
@Observable
public final class OnboardingViewModel {
    public private(set) var step: OnboardingStep = .welcome
    /// Providers whose SDK is actually wired on this platform/build.
    public let signInOptions: [OnboardingSignInOption]
    public private(set) var isSigningIn = false
    public private(set) var signInFailed = false

    private let requestLocation: @Sendable () async -> Void
    private let requestNotifications: @Sendable () async -> Void
    private let performSignIn: @Sendable (String) async -> Bool
    private let completionStore: OnboardingCompletionStore
    private let onFinished: @Sendable () -> Void

    public init(
        requestLocation: @escaping @Sendable () async -> Void,
        requestNotifications: @escaping @Sendable () async -> Void,
        signInOptions: [OnboardingSignInOption] = [],
        performSignIn: @escaping @Sendable (String) async -> Bool = { _ in false },
        completionStore: OnboardingCompletionStore,
        onFinished: @escaping @Sendable () -> Void
    ) {
        self.requestLocation = requestLocation
        self.requestNotifications = requestNotifications
        self.signInOptions = signInOptions
        self.performSignIn = performSignIn
        self.completionStore = completionStore
        self.onFinished = onFinished
    }

    public func advance() {
        guard let next = OnboardingStep(rawValue: step.rawValue + 1) else {
            finish()
            return
        }
        // Nothing to offer (e.g. no provider SDK wired) — don't show an empty
        // screen, just finish.
        if next == .signIn, signInOptions.isEmpty {
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
    /// prompt, then moves on regardless of outcome.
    public func allowNotifications() async {
        await requestNotifications()
        advance()
    }

    /// Taps a provider on the sign-in screen. Success finishes onboarding;
    /// failure keeps the user here with a message (cancelling is silent — the
    /// closure reports false and we simply stay put). Either way the account
    /// is optional: "Continue as guest" is always available.
    public func signIn(with optionId: String) async {
        isSigningIn = true
        signInFailed = false
        let succeeded = await performSignIn(optionId)
        isSigningIn = false
        if succeeded {
            finish()
        } else {
            signInFailed = true
        }
    }

    /// "Continue as guest" — the app is fully usable without an account.
    public func continueAsGuest() {
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
