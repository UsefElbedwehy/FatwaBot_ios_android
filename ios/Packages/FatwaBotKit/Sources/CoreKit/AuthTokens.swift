import Foundation

/// Session tokens from /v1/auth/{anonymous,refresh,apple,google} (ADR-0004).
/// Clients treat access_token as opaque; refresh_token is single-use.
public struct AuthTokens: Codable, Sendable, Equatable {
    public let userId: String
    public let accessToken: String
    public let refreshToken: String
    public let expiresAt: Date

    public init(userId: String, accessToken: String, refreshToken: String, expiresAt: Date) {
        self.userId = userId
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
    }
}

/// Persistence boundary for tokens — Keychain in production, in-memory for
/// tests/previews. Lives in CoreKit so both NetworkingKit and feature test
/// targets can depend on the protocol without pulling in Security framework
/// specifics.
public protocol AuthTokenStoring: Sendable {
    func load() -> AuthTokens?
    func save(_ tokens: AuthTokens)
    func clear()
}

public final class InMemoryAuthTokenStore: AuthTokenStoring, @unchecked Sendable {
    private var tokens: AuthTokens?
    private let lock = NSLock()

    public init(tokens: AuthTokens? = nil) {
        self.tokens = tokens
    }

    public func load() -> AuthTokens? {
        lock.lock(); defer { lock.unlock() }
        return tokens
    }

    public func save(_ tokens: AuthTokens) {
        lock.lock(); defer { lock.unlock() }
        self.tokens = tokens
    }

    public func clear() {
        lock.lock(); defer { lock.unlock() }
        tokens = nil
    }
}
