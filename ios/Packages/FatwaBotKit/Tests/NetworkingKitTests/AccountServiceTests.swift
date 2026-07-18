import XCTest
import Foundation
@testable import NetworkingKit

/// Records requests and replays canned JSON per "METHOD path". A `nil` entry
/// (or a registered error) lets a test drive failure paths.
private final class MockAuthedClient: AuthenticatedAPIClientProtocol, @unchecked Sendable {
    var responses: [String: Data] = [:]
    var errors: [String: Error] = [:]
    private(set) var calls: [String] = []

    private func reply<Response: Decodable>(_ key: String) throws -> Response {
        calls.append(key)
        if let error = errors[key] { throw error }
        let data = responses[key] ?? Data("{}".utf8)
        return try JSONDecoder().decode(Response.self, from: data)
    }

    func get<Response: Decodable & Sendable>(_ path: String, query: [URLQueryItem]) async throws -> Response {
        try reply("GET \(path)")
    }
    func post<Body: Encodable & Sendable, Response: Decodable & Sendable>(_ path: String, body: Body) async throws -> Response {
        try reply("POST \(path)")
    }
    func postEmpty<Response: Decodable & Sendable>(_ path: String) async throws -> Response {
        try reply("POST \(path)")
    }
    func patch<Body: Encodable & Sendable, Response: Decodable & Sendable>(_ path: String, body: Body) async throws -> Response {
        try reply("PATCH \(path)")
    }
    func delete<Response: Decodable & Sendable>(_ path: String) async throws -> Response {
        try reply("DELETE \(path)")
    }
}

final class AccountServiceTests: XCTestCase {
    func testMeDecodesProviderAndDisplayName() async throws {
        let client = MockAuthedClient()
        client.responses["GET v1/me"] = Data(#"{"user_id":"u1","display_name":"Zaid","provider":"apple"}"#.utf8)
        let profile = try await AccountService(client: client).me()
        XCTAssertEqual(profile.userId, "u1")
        XCTAssertEqual(profile.displayName, "Zaid")
        XCTAssertEqual(profile.provider, .apple)
        XCTAssertTrue(profile.isSignedIn)
    }

    func testMeDefaultsToAnonymousWhenProviderMissing() async throws {
        let client = MockAuthedClient()
        client.responses["GET v1/me"] = Data(#"{"user_id":"u1","display_name":null}"#.utf8)
        let profile = try await AccountService(client: client).me()
        XCTAssertEqual(profile.provider, .anonymous)
        XCTAssertFalse(profile.isSignedIn)
        XCTAssertNil(profile.displayName)
    }

    func testUpdateDisplayNamePatchesThenReloads() async throws {
        let client = MockAuthedClient()
        client.responses["PATCH v1/me/profile"] = Data("{}".utf8)
        client.responses["GET v1/me"] = Data(#"{"user_id":"u1","display_name":"Sara","provider":"anonymous"}"#.utf8)
        let profile = try await AccountService(client: client).updateDisplayName("  Sara  ")
        XCTAssertEqual(profile.displayName, "Sara")
        XCTAssertEqual(client.calls, ["PATCH v1/me/profile", "GET v1/me"])
    }

    func testLinkPostsThenReloadsProfile() async throws {
        let client = MockAuthedClient()
        client.responses["POST v1/auth/link"] = Data(#"{"user_id":"u1","provider":"google","linked":true}"#.utf8)
        client.responses["GET v1/me"] = Data(#"{"user_id":"u1","display_name":"Sara","provider":"google"}"#.utf8)
        let profile = try await AccountService(client: client).link(provider: .google, identityToken: "google.dev-abc")
        XCTAssertEqual(profile.provider, .google)
        XCTAssertEqual(client.calls, ["POST v1/auth/link", "GET v1/me"])
    }

    func testLinkMapsConflictToAlreadyLinked() async throws {
        let client = MockAuthedClient()
        client.errors["POST v1/auth/link"] = APIError.server(statusCode: 409, code: "already_linked")
        do {
            _ = try await AccountService(client: client).link(provider: .apple, identityToken: "apple.dev-abc")
            XCTFail("expected alreadyLinked")
        } catch let error as AccountServiceError {
            XCTAssertEqual(error, .alreadyLinked)
        }
    }

    func testLinkRejectsAnonymousProvider() async throws {
        let client = MockAuthedClient()
        do {
            _ = try await AccountService(client: client).link(provider: .anonymous, identityToken: "x")
            XCTFail("expected notLinkable")
        } catch let error as AccountServiceError {
            XCTAssertEqual(error, .notLinkable)
        }
    }

    func testStubCredentialProducesStableSubject() async throws {
        let defaults = UserDefaults(suiteName: "test.account.\(UUID().uuidString)")!
        let provider = StubProviderCredentialProvider(defaults: defaults)
        let a = try await provider.identityToken(for: .apple)
        let b = try await provider.identityToken(for: .apple)
        XCTAssertEqual(a, b)                       // stable across calls
        XCTAssertTrue(a.hasPrefix("apple."))
        XCTAssertTrue(provider.isConfigured(.google))
    }
}
