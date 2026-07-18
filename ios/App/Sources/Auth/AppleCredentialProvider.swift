import AuthenticationServices
import Foundation
import NetworkingKit
import UIKit

/// Real Sign in with Apple. Presents the system sheet and returns the signed
/// identity token (a JWT) for `POST /v1/auth/link`, where the backend verifies
/// it against Apple's JWKS with audience `com.fatwabot.app`.
///
/// Requires the "Sign in with Apple" capability + entitlement (present since
/// the Apple Developer Program was provisioned).
final class AppleCredentialProvider: NSObject, ProviderCredentialProviding, @unchecked Sendable {
    private var continuation: CheckedContinuation<String, Error>?

    func isConfigured(_ provider: AccountProvider) -> Bool { provider == .apple }

    func identityToken(for provider: AccountProvider) async throws -> String {
        guard provider == .apple else { throw ProviderSignInError.unsupported }
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            Task { @MainActor in
                self.continuation = continuation
                let request = ASAuthorizationAppleIDProvider().createRequest()
                request.requestedScopes = [.fullName, .email]
                let controller = ASAuthorizationController(authorizationRequests: [request])
                controller.delegate = self
                controller.presentationContextProvider = self
                controller.performRequests()
            }
        }
    }

    private func finish(_ result: Result<String, Error>) {
        continuation?.resume(with: result)
        continuation = nil
    }
}

extension AppleCredentialProvider: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard
            let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let tokenData = credential.identityToken,
            let token = String(data: tokenData, encoding: .utf8)
        else {
            finish(.failure(ProviderSignInError.failed("Apple returned no identity token")))
            return
        }
        finish(.success(token))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        if let authError = error as? ASAuthorizationError, authError.code == .canceled {
            finish(.failure(ProviderSignInError.cancelled))
        } else {
            finish(.failure(ProviderSignInError.failed(error.localizedDescription)))
        }
    }
}

extension AppleCredentialProvider: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.first(where: { $0.activationState == .foregroundActive })?.keyWindow
            ?? scenes.first?.keyWindow
        return window ?? ASPresentationAnchor()
    }
}

/// Routes each provider to its real implementation, falling back to the dev
/// stub for providers whose SDK isn't wired yet (Google — pending the
/// GoogleSignIn package). Keeps one seam for the ViewModel.
final class CompositeCredentialProvider: ProviderCredentialProviding, @unchecked Sendable {
    private let apple: ProviderCredentialProviding
    private let google: ProviderCredentialProviding

    init(apple: ProviderCredentialProviding, google: ProviderCredentialProviding) {
        self.apple = apple
        self.google = google
    }

    /// Google is intentionally reported unconfigured until the GoogleSignIn SDK
    /// replaces the stub — the backend now verifies real tokens, so a stub
    /// Google token would 401. Removing this line is the only change needed
    /// once the SDK lands.
    private let googleSDKWired = false

    func isConfigured(_ provider: AccountProvider) -> Bool {
        switch provider {
        case .apple: return apple.isConfigured(.apple)
        case .google: return googleSDKWired && google.isConfigured(.google)
        case .anonymous: return false
        }
    }

    func identityToken(for provider: AccountProvider) async throws -> String {
        switch provider {
        case .apple: return try await apple.identityToken(for: .apple)
        case .google: return try await google.identityToken(for: .google)
        case .anonymous: throw ProviderSignInError.unsupported
        }
    }
}
