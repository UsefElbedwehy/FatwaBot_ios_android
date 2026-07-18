import Foundation

/// Obtains a provider identity token to hand to `POST /v1/auth/link`.
///
/// The seam that keeps the account feature buildable and testable before the
/// Apple Developer Program (Sign in with Apple entitlement) and a Google OAuth
/// client exist — mirrors `IdentityProviderVerifier` on the backend and the
/// gated iOS-push drop-in (docs/features/push-notifications.md).
///
/// - `StubProviderCredentialProvider` (default today) returns a deterministic
///   per-install token that the backend's `DevIdentityProviderVerifier` accepts,
///   so the whole sign-in → link → profile flow works end-to-end against the
///   live function right now.
/// - The real `AppleCredentialProvider` (ASAuthorizationController) / Google
///   provider drop in unchanged once those credentials are provisioned.
public protocol ProviderCredentialProviding: Sendable {
    /// Whether this provider can currently produce a real credential on this
    /// device/build (Apple entitlement present, Google configured, …).
    func isConfigured(_ provider: AccountProvider) -> Bool
    /// Returns the identity token, or throws if the user cancels / it fails.
    func identityToken(for provider: AccountProvider) async throws -> String
}

public enum ProviderSignInError: Error, Equatable {
    case cancelled
    case unsupported
    case failed(String)
}

/// Dev sign-in: no native provider SDK, no credentials required. Produces a
/// stable subject id per install (persisted) so re-signing in reuses the same
/// backend account. NOT production auth — a real verifier drops in later.
public final class StubProviderCredentialProvider: ProviderCredentialProviding, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "fatwabot.stub_provider_subject"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func isConfigured(_ provider: AccountProvider) -> Bool {
        provider == .apple || provider == .google
    }

    public func identityToken(for provider: AccountProvider) async throws -> String {
        guard provider == .apple || provider == .google else { throw ProviderSignInError.unsupported }
        let subject: String
        if let existing = defaults.string(forKey: key) {
            subject = existing
        } else {
            subject = "dev-\(UUID().uuidString.prefix(12))"
            defaults.set(subject, forKey: key)
        }
        // Backend dev verifier treats the token as the subject id directly.
        return "\(provider.rawValue).\(subject)"
    }
}
