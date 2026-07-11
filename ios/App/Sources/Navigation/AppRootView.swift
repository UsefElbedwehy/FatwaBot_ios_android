import Factory
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
                    completionStore: Container.shared.onboardingCompletionStore(),
                    onFinished: { isOnboardingCompleted = true }
                )
            )
        }
    }
}
