import XCTest
import CoreKit
@testable import NetworkingKit

private final class FakeTokenProvider: AuthTokenProviding, @unchecked Sendable {
    var currentToken: String
    var refreshedToken: String
    private(set) var refreshCallCount = 0

    init(currentToken: String, refreshedToken: String = "refreshed-tok") {
        self.currentToken = currentToken
        self.refreshedToken = refreshedToken
    }

    func validAccessToken() async throws -> String { currentToken }
    func invalidateAndRefresh() async throws -> String {
        refreshCallCount += 1
        currentToken = refreshedToken
        return refreshedToken
    }
}

private struct Echo: Codable, Equatable { let value: String }

final class AuthenticatedAPIClientTests: XCTestCase {
    private func makeClient(provider: AuthTokenProviding) -> AuthenticatedAPIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return AuthenticatedAPIClient(
            baseURL: URL(string: "https://example.supabase.co/functions/v1/api")!,
            context: ClientContext(appVersion: "1.0.0", locale: "ar"),
            tokenProvider: provider,
            session: URLSession(configuration: configuration)
        )
    }

    override func tearDown() {
        StubURLProtocol.handler = nil
        super.tearDown()
    }

    func testGetAttachesBearerTokenAndDecodes() async throws {
        StubURLProtocol.handler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "authorization"), "Bearer tok-1")
            XCTAssertEqual(request.httpMethod, "GET")
            return (200, Data(#"{"value":"hi"}"#.utf8))
        }
        let client = makeClient(provider: FakeTokenProvider(currentToken: "tok-1"))
        let result: Echo = try await client.get("v1/gamification/profile", query: [])
        XCTAssertEqual(result, Echo(value: "hi"))
    }

    func testPostSendsJSONBodyWithContentType() async throws {
        StubURLProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "content-type"), "application/json")
            return (201, Data(#"{"value":"created"}"#.utf8))
        }
        let client = makeClient(provider: FakeTokenProvider(currentToken: "tok-1"))
        let result: Echo = try await client.post("v1/search-history", body: Echo(value: "query"))
        XCTAssertEqual(result, Echo(value: "created"))
    }

    func test401TriggersOneRefreshAndRetry() async throws {
        final class Counter: @unchecked Sendable { var value = 0 }
        let counter = Counter()
        StubURLProtocol.handler = { request in
            counter.value += 1
            if counter.value == 1 {
                XCTAssertEqual(request.value(forHTTPHeaderField: "authorization"), "Bearer tok-1")
                return (401, Data(#"{"error":{"code":"unauthorized","message":"x"}}"#.utf8))
            }
            XCTAssertEqual(request.value(forHTTPHeaderField: "authorization"), "Bearer refreshed-tok")
            return (200, Data(#"{"value":"ok"}"#.utf8))
        }
        let provider = FakeTokenProvider(currentToken: "tok-1")
        let client = makeClient(provider: provider)
        let result: Echo = try await client.get("v1/gamification/profile", query: [])
        XCTAssertEqual(result, Echo(value: "ok"))
        XCTAssertEqual(provider.refreshCallCount, 1)
    }

    func testServerErrorAfterRetryStillSurfacesStructuredCode() async throws {
        StubURLProtocol.handler = { _ in
            (403, Data(#"{"error":{"code":"forbidden","message":"x"}}"#.utf8))
        }
        let client = makeClient(provider: FakeTokenProvider(currentToken: "tok-1"))
        do {
            let _: Echo = try await client.get("v1/gamification/profile", query: [])
            XCTFail("expected error")
        } catch let error as APIError {
            XCTAssertEqual(error, .server(statusCode: 403, code: "forbidden"))
        }
    }
}
