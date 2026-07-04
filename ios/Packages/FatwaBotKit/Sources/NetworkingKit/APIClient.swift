import CoreKit
import Foundation

/// Typed endpoint description; the full catalog lives in Endpoints.swift.
public struct Endpoint<Response: Decodable & Sendable>: Sendable {
    public let path: String
    public let query: [URLQueryItem]

    public init(path: String, query: [URLQueryItem] = []) {
        self.path = path
        self.query = query
    }
}

public struct ClientContext: Sendable {
    public let platform: String
    public let appVersion: String
    public let locale: String

    public init(platform: String = "ios", appVersion: String, locale: String) {
        self.platform = platform
        self.appVersion = appVersion
        self.locale = locale
    }
}

public enum APIError: Error, Equatable {
    case invalidURL
    case transport(String)
    case server(statusCode: Int, code: String?)
    case decoding(String)
}

/// Read path of the versioned REST API (ADR-0002). GET-only in M0; authenticated
/// writes arrive with /v1/auth in M1.
public protocol APIClientProtocol: Sendable {
    func get<Response: Decodable & Sendable>(_ endpoint: Endpoint<Response>) async throws -> Response
}

public final class APIClient: APIClientProtocol {
    private let baseURL: URL
    private let context: ClientContext
    private let session: URLSession

    public init(baseURL: URL, context: ClientContext, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.context = context
        self.session = session
    }

    public func get<Response: Decodable & Sendable>(_ endpoint: Endpoint<Response>) async throws -> Response {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent(endpoint.path),
            resolvingAgainstBaseURL: false
        ) else { throw APIError.invalidURL }
        if !endpoint.query.isEmpty { components.queryItems = endpoint.query }
        guard let url = components.url else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.setValue(context.platform, forHTTPHeaderField: "x-client-platform")
        request.setValue(context.appVersion, forHTTPHeaderField: "x-client-version")
        request.setValue(context.locale, forHTTPHeaderField: "x-client-locale")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.transport("Non-HTTP response")
        }
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

struct ErrorEnvelope: Decodable {
    struct Payload: Decodable {
        let code: String
        let message: String
    }

    let error: Payload
}
