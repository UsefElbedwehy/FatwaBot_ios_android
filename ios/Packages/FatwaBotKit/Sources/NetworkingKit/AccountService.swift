import Foundation

/// The three identity kinds the backend recognises (docs/features/accounts.md).
/// Anonymous is the default (ADR-0004); linking to Apple/Google preserves the
/// same `user_id` — no data migration.
public enum AccountProvider: String, Sendable, Equatable {
    case anonymous
    case apple
    case google
}

/// A snapshot of the current account from `GET /v1/me`.
public struct AccountProfile: Sendable, Equatable {
    public let userId: String
    public let displayName: String?
    public let provider: AccountProvider

    public init(userId: String, displayName: String?, provider: AccountProvider) {
        self.userId = userId
        self.displayName = displayName
        self.provider = provider
    }

    public var isSignedIn: Bool { provider != .anonymous }
}

/// Reads and mutates the signed-in account. Wraps the authenticated client so
/// feature code never touches raw endpoints.
public protocol AccountServicing: Sendable {
    /// Current account state (`GET /v1/me`).
    func me() async throws -> AccountProfile
    /// Sets or clears the user-chosen display name (`PATCH /v1/me/profile`);
    /// returns the refreshed profile.
    func updateDisplayName(_ name: String?) async throws -> AccountProfile
    /// Upgrades the current anonymous identity to a provider account without
    /// changing `user_id` (`POST /v1/auth/link`). Returns the refreshed profile.
    /// Throws `.alreadyLinked` if that provider identity belongs to another account.
    func link(provider: AccountProvider, identityToken: String) async throws -> AccountProfile
}

public enum AccountServiceError: Error, Equatable {
    case alreadyLinked
    case notLinkable
}

private struct MeDTO: Decodable {
    let user_id: String
    let display_name: String?
    let provider: String?
}

private struct UpdateProfileRequest: Encodable {
    let display_name: String?
}

private struct LinkRequest: Encodable {
    let provider: String
    let identity_token: String
}

public struct AccountService: AccountServicing {
    private let client: AuthenticatedAPIClientProtocol

    public init(client: AuthenticatedAPIClientProtocol) {
        self.client = client
    }

    public func me() async throws -> AccountProfile {
        let dto: MeDTO = try await client.get("v1/me", query: [])
        return AccountProfile(
            userId: dto.user_id,
            displayName: dto.display_name,
            provider: AccountProvider(rawValue: dto.provider ?? "anonymous") ?? .anonymous
        )
    }

    public func updateDisplayName(_ name: String?) async throws -> AccountProfile {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = (trimmed?.isEmpty ?? true) ? nil : trimmed
        // Response body is ignored — we re-read /v1/me for the canonical profile.
        let _: IgnoredResponse = try await client.patch("v1/me/profile", body: UpdateProfileRequest(display_name: value))
        return try await me()
    }

    public func link(provider: AccountProvider, identityToken: String) async throws -> AccountProfile {
        guard provider == .apple || provider == .google else { throw AccountServiceError.notLinkable }
        do {
            let _: IgnoredResponse = try await client.post(
                "v1/auth/link",
                body: LinkRequest(provider: provider.rawValue, identity_token: identityToken)
            )
        } catch APIError.server(statusCode: 409, code: _) {
            throw AccountServiceError.alreadyLinked
        }
        return try await me()
    }
}

/// Decodes successfully from any JSON object — used when we don't care about
/// the response body (we re-read /v1/me afterwards).
private struct IgnoredResponse: Decodable {}
