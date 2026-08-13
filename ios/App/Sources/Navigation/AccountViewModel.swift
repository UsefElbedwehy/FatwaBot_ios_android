import Foundation
import NetworkingKit
import SwiftUI

/// Drives the account section of Settings — loads `GET /v1/me`, edits the
/// display name, and links the anonymous identity to Apple/Google.
@MainActor
final class AccountViewModel: ObservableObject {
    @Published private(set) var profile: AccountProfile?
    @Published private(set) var isLoading = false
    @Published private(set) var isBusy = false
    @Published var errorMessage: String?

    private let account: AccountServicing
    private let credentials: ProviderCredentialProviding

    init(account: AccountServicing, credentials: ProviderCredentialProviding) {
        self.account = account
        self.credentials = credentials
    }

    var providerLabel: LocalizedStringKey {
        switch profile?.provider ?? .anonymous {
        case .anonymous: return "settings.account.provider.guest"
        case .apple: return "settings.account.provider.apple"
        case .google: return "settings.account.provider.google"
        }
    }

    var isSignedIn: Bool { profile?.isSignedIn ?? false }

    /// Only offer a provider whose real SDK/entitlement is wired — otherwise the
    /// button would fail against the backend's real token verification.
    func isAvailable(_ provider: AccountProvider) -> Bool {
        credentials.isConfigured(provider)
    }

    func load() async {
        guard profile == nil else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            profile = try await account.me()
        } catch {
            // Left `profile == nil` (renders as Guest) rather than fabricating
            // a signed-in state — but unlike before, this is no longer silent:
            // a transient failure here used to look identical to a genuine
            // guest, with nothing telling a signed-in user why they suddenly
            // appear signed out.
            errorMessage = String(localized: "settings.account.error.generic")
        }
    }

    func reload() async {
        errorMessage = nil
        do {
            profile = try await account.me()
        } catch {
            errorMessage = String(localized: "settings.account.error.generic")
        }
    }

    func saveDisplayName(_ name: String) async {
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            profile = try await account.updateDisplayName(name)
        } catch {
            errorMessage = String(localized: "settings.account.error.generic")
        }
    }

    func signIn(with provider: AccountProvider) async {
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            let token = try await credentials.identityToken(for: provider)
            profile = try await account.link(provider: provider, identityToken: token)
        } catch ProviderSignInError.cancelled {
            // user backed out — no error surfaced
        } catch AccountServiceError.alreadyLinked {
            errorMessage = String(localized: "settings.account.error.already_linked")
        } catch {
            errorMessage = String(localized: "settings.account.error.generic")
        }
    }
}
