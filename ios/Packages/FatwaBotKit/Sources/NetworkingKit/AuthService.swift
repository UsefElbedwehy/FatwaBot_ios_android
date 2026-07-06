import CoreKit
import Foundation

/// Supplies a valid access token for authenticated calls, transparently
/// signing in anonymously (ADR-0004) on first use and refreshing before/after
/// expiry. One instance per app process; token state is cached in memory and
/// persisted via `AuthTokenStoring`.
public protocol AuthTokenProviding: Sendable {
    func validAccessToken() async throws -> String
    /// Forces a refresh (or a fresh anonymous sign-in if there's nothing to
    /// refresh) — called after a 401 to retry a request exactly once.
    func invalidateAndRefresh() async throws -> String
}

private struct DeviceRegistrationPayload: Encodable {
    let platform: String
    let app_version: String
    let locale: String
    let timezone: String
}

private struct AnonymousAuthRequest: Encodable {
    let device: DeviceRegistrationPayload
}

private struct RefreshRequest: Encodable {
    let refresh_token: String
}

private struct TokenResponseDTO: Decodable {
    let user_id: String
    let access_token: String
    let expires_in: Int
    let refresh_token: String
}

public actor AuthService: AuthTokenProviding {
    private let baseURL: URL
    private let context: ClientContext
    private let store: AuthTokenStoring
    private let session: URLSession
    private var cached: AuthTokens?
    /// Refresh proactively this many seconds before expiry.
    private let expiryBuffer: TimeInterval = 60

    public init(baseURL: URL, context: ClientContext, store: AuthTokenStoring, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.context = context
        self.store = store
        self.session = session
        self.cached = store.load()
    }

    public func validAccessToken() async throws -> String {
        if let cached, cached.expiresAt.timeIntervalSinceNow > expiryBuffer {
            return cached.accessToken
        }
        if let cached {
            if let refreshed = try? await refresh(using: cached.refreshToken) {
                return refreshed.accessToken
            }
        }
        return try await signInAnonymous().accessToken
    }

    public func invalidateAndRefresh() async throws -> String {
        guard let cached else { return try await signInAnonymous().accessToken }
        if let refreshed = try? await refresh(using: cached.refreshToken) {
            return refreshed.accessToken
        }
        return try await signInAnonymous().accessToken
    }

    private func signInAnonymous() async throws -> AuthTokens {
        let device = DeviceRegistrationPayload(
            platform: context.platform,
            app_version: context.appVersion,
            locale: context.locale,
            timezone: TimeZone.current.identifier
        )
        let dto: TokenResponseDTO = try await postUnauthenticated(
            "v1/auth/anonymous",
            body: AnonymousAuthRequest(device: device)
        )
        return persist(dto)
    }

    private func refresh(using refreshToken: String) async throws -> AuthTokens {
        let dto: TokenResponseDTO = try await postUnauthenticated(
            "v1/auth/refresh",
            body: RefreshRequest(refresh_token: refreshToken)
        )
        return persist(dto)
    }

    private func persist(_ dto: TokenResponseDTO) -> AuthTokens {
        let tokens = AuthTokens(
            userId: dto.user_id,
            accessToken: dto.access_token,
            refreshToken: dto.refresh_token,
            expiresAt: Date().addingTimeInterval(TimeInterval(dto.expires_in))
        )
        cached = tokens
        store.save(tokens)
        return tokens
    }

    private func postUnauthenticated<Body: Encodable, Response: Decodable>(_ path: String, body: Body) async throws -> Response {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(context.platform, forHTTPHeaderField: "x-client-platform")
        request.setValue(context.appVersion, forHTTPHeaderField: "x-client-version")
        request.setValue(context.locale, forHTTPHeaderField: "x-client-locale")
        request.httpBody = try JSONEncoder().encode(body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else { throw APIError.transport("Non-HTTP response") }
        guard (200..<300).contains(http.statusCode) else {
            let envelope = try? JSONDecoder().decode(ErrorEnvelope.self, from: data)
            throw APIError.server(statusCode: http.statusCode, code: envelope?.error.code)
        }
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }
}
