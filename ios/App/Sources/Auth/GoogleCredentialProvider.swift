import Foundation
import GoogleSignIn
import NetworkingKit
import UIKit

/// Real Google Sign-In. Presents Google's sheet and returns the OIDC **ID
/// token**, which the backend verifies against Google's JWKS (audience = this
/// iOS client id, which `GoogleIdentityVerifier` accepts alongside the web one).
///
/// No `GoogleService-Info.plist` is bundled — we're not using Firebase Auth, so
/// the client id is supplied directly and the only project-level requirement is
/// the reversed-client-id URL scheme in Info.plist (see project.yml).
final class GoogleCredentialProvider: ProviderCredentialProviding, @unchecked Sendable {
    /// iOS OAuth client id from the Firebase project (public identifier).
    static let clientID = "665767164439-gbe98ql9lddnddflkmev7vaira6mako3.apps.googleusercontent.com"

    func isConfigured(_ provider: AccountProvider) -> Bool { provider == .google }

    func identityToken(for provider: AccountProvider) async throws -> String {
        guard provider == .google else { throw ProviderSignInError.unsupported }

        do {
            return try await presentAndFetchIDToken()
        } catch let error as ProviderSignInError {
            throw error
        } catch {
            if (error as NSError).code == GIDSignInError.canceled.rawValue {
                throw ProviderSignInError.cancelled
            }
            throw ProviderSignInError.failed(error.localizedDescription)
        }
    }

    /// The SDK is main-actor bound; awaiting inside a `@MainActor` method hops
    /// once and keeps the async `signIn` overload (the sync one returns Void).
    @MainActor
    private func presentAndFetchIDToken() async throws -> String {
        guard let presenter = Self.topViewController() else {
            throw ProviderSignInError.failed("No view controller to present from")
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: Self.clientID)
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
        guard let idToken = result.user.idToken?.tokenString else {
            throw ProviderSignInError.failed("Google returned no ID token")
        }
        return idToken
    }

    @MainActor
    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.first(where: { $0.activationState == .foregroundActive })?.keyWindow
            ?? scenes.first?.keyWindow
        var top = window?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
