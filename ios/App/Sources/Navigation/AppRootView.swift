import Factory
import NetworkingKit
import OnboardingFeature
import SwiftUI

/// Top-level gate: shows the value-first onboarding flow (docs/features/onboarding.md)
/// once per install, then RootTabView forever after. Onboarding has no
/// identity to attach completion to (it runs before any auth call), so this
/// is a pure local-file check — a reinstall sees onboarding again.
struct AppRootView: View {
    @State private var isOnboardingCompleted = Container.shared.onboardingCompletionStore().isCompleted()

    var body: some View {
        if isOnboardingCompleted {
            RootTabView()
        } else {
            OnboardingScreen(
                viewModel: OnboardingViewModel(
                    requestLocation: { _ = await Container.shared.locationProvider().resolve() },
                    requestNotifications: { _ = await Container.shared.notificationScheduler().requestAuthorization() },
                    signInOptions: Self.signInOptions,
                    performSignIn: { optionId in await Self.signIn(optionId) },
                    completionStore: Container.shared.onboardingCompletionStore(),
                    onFinished: { isOnboardingCompleted = true }
                )
            )
        }
    }

    /// Only providers whose SDK/entitlement is actually wired — an empty list
    /// makes the onboarding VM skip the sign-in step entirely.
    private static var signInOptions: [OnboardingSignInOption] {
        let credentials = Container.shared.providerCredential()
        var options: [OnboardingSignInOption] = []
        if credentials.isConfigured(.apple) {
            options.append(OnboardingSignInOption(
                id: AccountProvider.apple.rawValue,
                titleKey: "settings.account.sign_in_apple",
                systemImage: "apple.logo"
            ))
        }
        if credentials.isConfigured(.google) {
            options.append(OnboardingSignInOption(
                id: AccountProvider.google.rawValue,
                titleKey: "settings.account.sign_in_google",
                systemImage: "g.circle.fill"
            ))
        }
        return options
    }

    /// Links the just-created anonymous identity to the chosen provider, so all
    /// onboarding-time state carries over. Returns false on cancel/failure — the
    /// VM then keeps the user on the step rather than dropping them into the app.
    private static func signIn(_ optionId: String) async -> Bool {
        guard let provider = AccountProvider(rawValue: optionId) else { return false }
        do {
            let token = try await Container.shared.providerCredential().identityToken(for: provider)
            _ = try await Container.shared.accountService().link(provider: provider, identityToken: token)
            return true
        } catch {
            return false
        }
    }
}
