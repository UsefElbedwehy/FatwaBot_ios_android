import DesignSystemKit
import SwiftUI

public struct OnboardingScreen: View {
    @State private var viewModel: OnboardingViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isBusy = false

    public init(viewModel: OnboardingViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    private var tokens: ColorTokens {
        let base = DesignTokens.bundledDefault
        return colorScheme == .dark ? base.dark : base.light
    }

    public var body: some View {
        VStack(spacing: 0) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(reduceMotion ? .opacity : .asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .animation(reduceMotion ? .linear(duration: 0.1) : .easeInOut, value: viewModel.step)
        }
        .background(Color(hexToken: tokens.surface))
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.step {
        case .welcome:
            WelcomeStepView(tokens: tokens) { viewModel.advance() }
        case .highlights:
            HighlightsStepView(tokens: tokens) { viewModel.advance() }
        case .locationPriming:
            PrimingStepView(
                systemImage: "location.fill",
                titleKey: "onboarding.location.title",
                bodyKey: "onboarding.location.body",
                tokens: tokens,
                isBusy: isBusy,
                onAllow: {
                    isBusy = true
                    await viewModel.allowLocation()
                    isBusy = false
                },
                onSkip: { viewModel.skip() }
            )
        case .notificationPriming:
            PrimingStepView(
                systemImage: "bell.fill",
                titleKey: "onboarding.notifications.title",
                bodyKey: "onboarding.notifications.body",
                tokens: tokens,
                isBusy: isBusy,
                onAllow: {
                    isBusy = true
                    await viewModel.allowNotifications()
                    isBusy = false
                },
                onSkip: { viewModel.skip() }
            )
        case .signIn:
            SignInStepView(viewModel: viewModel, tokens: tokens)
        }
    }
}

/// Optional account step — last, and always escapable via "Continue as guest"
/// (docs/features/accounts.md: sign-in is never a wall).
private struct SignInStepView: View {
    let viewModel: OnboardingViewModel
    let tokens: ColorTokens

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            ArchIconBadge(systemImage: "person.crop.circle.badge.checkmark", tokens: tokens)
            Text("onboarding.signin.title")
                .font(.title.weight(.bold))
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text("onboarding.signin.body")
                .font(.body)
                .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                .multilineTextAlignment(.center)
            Spacer()

            if viewModel.signInFailed {
                Text("onboarding.signin.failed")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            ForEach(viewModel.signInOptions) { option in
                Button {
                    Task { await viewModel.signIn(with: option.id) }
                } label: {
                    Group {
                        if viewModel.isSigningIn {
                            ProgressView().tint(.white)
                        } else {
                            Label(LocalizedStringKey(option.titleKey), systemImage: option.systemImage)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(Color(hexToken: tokens.primary))
                .disabled(viewModel.isSigningIn)
            }

            Button("onboarding.signin.guest") { viewModel.continueAsGuest() }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                .disabled(viewModel.isSigningIn)
        }
        .padding(24)
    }
}

private struct WelcomeStepView: View {
    let tokens: ColorTokens
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            ArchIconBadge(systemImage: "moon.stars.fill", tokens: tokens, size: CGSize(width: 108, height: 122))
            Text("onboarding.welcome.title")
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text("onboarding.welcome.subtitle")
                .font(.body)
                .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                .multilineTextAlignment(.center)
            Spacer()
            Button {
                onContinue()
            } label: {
                Text("onboarding.get_started")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(Color(hexToken: tokens.primary))
        }
        .padding(24)
    }
}

private struct HighlightsStepView: View {
    let tokens: ColorTokens
    let onContinue: () -> Void

    private let cards: [(icon: String, titleKey: String)] = [
        ("clock.fill", "onboarding.highlight.prayer"),
        ("book.closed.fill", "onboarding.highlight.worship"),
        ("flame.fill", "onboarding.highlight.streaks"),
    ]

    var body: some View {
        VStack(spacing: 20) {
            Text("onboarding.highlights.title")
                .font(.title.weight(.bold))
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, 32)

            TabView {
                ForEach(cards, id: \.titleKey) { card in
                    VStack(spacing: 16) {
                        ArchIconBadge(systemImage: card.icon, tokens: tokens)
                        Text(LocalizedStringKey(card.titleKey))
                            .font(.title3.weight(.semibold))
                            .multilineTextAlignment(.center)
                    }
                    .padding(32)
                    .frame(maxWidth: .infinity)
                }
            }
            #if os(iOS)
            .tabViewStyle(.page)
            #endif

            Button {
                onContinue()
            } label: {
                Text("onboarding.continue")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(Color(hexToken: tokens.primary))
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
}

private struct PrimingStepView: View {
    let systemImage: String
    let titleKey: String
    let bodyKey: String
    let tokens: ColorTokens
    let isBusy: Bool
    let onAllow: () async -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            ArchIconBadge(systemImage: systemImage, tokens: tokens)
            Text(LocalizedStringKey(titleKey))
                .font(.title.weight(.bold))
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text(LocalizedStringKey(bodyKey))
                .font(.body)
                .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                .multilineTextAlignment(.center)
            Spacer()
            Button {
                Task { await onAllow() }
            } label: {
                Group {
                    if isBusy {
                        ProgressView().tint(.white)
                    } else {
                        Text("onboarding.allow")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(Color(hexToken: tokens.primary))
            .disabled(isBusy)

            Button("onboarding.not_now") { onSkip() }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                .disabled(isBusy)
        }
        .padding(24)
    }
}
