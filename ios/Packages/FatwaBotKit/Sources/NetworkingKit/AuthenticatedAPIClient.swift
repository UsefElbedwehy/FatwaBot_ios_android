import CoreKit
import Foundation

/// Write/authenticated-read path of the versioned REST API — everything that
/// needs a bearer token (gamification, leaderboards, search history,
/// notifications, profile). Kept separate from `APIClientProtocol` (GET-only,
/// unauthenticated) so M0/M1/M2 read paths and their test doubles are
/// untouched (ADR-0002).
public protocol AuthenticatedAPIClientProtocol: Sendable {
    func get<Response: Decodable & Sendable>(_ path: String, query: [URLQueryItem]) async throws -> Response
    func post<Body: Encodable & Sendable, Response: Decodable & Sendable>(_ path: String, body: Body) async throws -> Response
    func postEmpty<Response: Decodable & Sendable>(_ path: String) async throws -> Response
    func patch<Body: Encodable & Sendable, Response: Decodable & Sendable>(_ path: String, body: Body) async throws -> Response
    func delete<Response: Decodable & Sendable>(_ path: String) async throws -> Response
}

public final class AuthenticatedAPIClient: AuthenticatedAPIClientProtocol {
    private let baseURL: URL
    private let context: ClientContext
    private let session: URLSession
    private let tokenProvider: AuthTokenProviding

    public init(baseURL: URL, context: ClientContext, tokenProvider: AuthTokenProviding, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.context = context
        self.session = session
        self.tokenProvider = tokenProvider
    }

    public func get<Response: Decodable & Sendable>(_ path: String, query: [URLQueryItem] = []) async throws -> Response {
        try await send(path: path, method: "GET", query: query, bodyData: nil)
    }

    public func post<Body: Encodable & Sendable, Response: Decodable & Sendable>(_ path: String, body: Body) async throws -> Response {
        try await send(path: path, method: "POST", query: [], bodyData: try encode(body))
    }

    public func postEmpty<Response: Decodable & Sendable>(_ path: String) async throws -> Response {
        try await send(path: path, method: "POST", query: [], bodyData: nil)
    }

    public func patch<Body: Encodable & Sendable, Response: Decodable & Sendable>(_ path: String, body: Body) async throws -> Response {
        try await send(path: path, method: "PATCH", query: [], bodyData: try encode(body))
    }

    public func delete<Response: Decodable & Sendable>(_ path: String) async throws -> Response {
        try await send(path: path, method: "DELETE", query: [], bodyData: nil)
    }

    private func encode<Body: Encodable>(_ body: Body) throws -> Data {
        do {
            return try JSONEncoder().encode(body)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }

    private func send<Response: Decodable>(path: String, method: String, query: [URLQueryItem], bodyData: Data?) async throws -> Response {
        let firstToken = try await tokenProvider.validAccessToken()
        let (data, http) = try await perform(path: path, method: method, query: query, bodyData: bodyData, token: firstToken)

        if http.statusCode == 401 {
            let retryToken = try await tokenProvider.invalidateAndRefresh()
            let (retryData, retryHTTP) = try await perform(path: path, method: method, query: query, bodyData: bodyData, token: retryToken)
            return try decodeOrThrow(retryData, retryHTTP)
        }
        return try decodeOrThrow(data, http)
    }

    private func perform(
        path: String,
        method: String,
        query: [URLQueryItem],
        bodyData: Data?,
        token: String
    ) async throws -> (Data, HTTPURLResponse) {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        ) else { throw APIError.invalidURL }
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(context.platform, forHTTPHeaderField: "x-client-platform")
        request.setValue(context.appVersion, forHTTPHeaderField: "x-client-version")
        request.setValue(context.locale, forHTTPHeaderField: "x-client-locale")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "authorization")
        if let bodyData {
            request.httpBody = bodyData
            request.setValue("application/json", forHTTPHeaderField: "content-type")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else { throw APIError.transport("Non-HTTP response") }
        return (data, http)
    }

    private func decodeOrThrow<Response: Decodable>(_ data: Data, _ http: HTTPURLResponse) throws -> Response {
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
