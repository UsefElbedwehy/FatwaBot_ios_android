import XCTest
import CoreKit
@testable import NetworkingKit

final class AuthServiceTests: XCTestCase {
    private func makeService(store: AuthTokenStoring = InMemoryAuthTokenStore()) -> AuthService {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return AuthService(
            baseURL: URL(string: "https://example.supabase.co/functions/v1/api")!,
            context: ClientContext(appVersion: "1.0.0", locale: "ar"),
            store: store,
            session: URLSession(configuration: configuration)
        )
    }

    override func tearDown() {
        StubURLProtocol.handler = nil
        super.tearDown()
    }

    func testFirstCallSignsInAnonymouslyAndPersists() async throws {
        let store = InMemoryAuthTokenStore()
        StubURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/functions/v1/api/v1/auth/anonymous")
            XCTAssertEqual(request.httpMethod, "POST")
            let body = #"{"user_id":"u1","kind":"anonymous","access_token":"tok-1","expires_in":3600,"refresh_token":"rt-1"}"#
            return (200, Data(body.utf8))
        }
        let token = try await makeService(store: store).validAccessToken()
        XCTAssertEqual(token, "tok-1")
        XCTAssertEqual(store.load()?.userId, "u1")
    }

    func testCachedNonExpiredTokenIsReusedWithoutANetworkCall() async throws {
        let store = InMemoryAuthTokenStore(tokens: AuthTokens(
            userId: "u1", accessToken: "cached-tok", refreshToken: "rt-1",
            expiresAt: Date().addingTimeInterval(3600)
        ))
        StubURLProtocol.handler = { _ in XCTFail("should not hit the network"); return (500, Data()) }
        let token = try await makeService(store: store).validAccessToken()
        XCTAssertEqual(token, "cached-tok")
    }

    func testExpiringTokenTriggersARefreshCall() async throws {
        let store = InMemoryAuthTokenStore(tokens: AuthTokens(
            userId: "u1", accessToken: "old-tok", refreshToken: "rt-1",
            expiresAt: Date().addingTimeInterval(10) // inside the 60s buffer
        ))
        StubURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/functions/v1/api/v1/auth/refresh")
            let body = #"{"user_id":"u1","kind":"anonymous","access_token":"new-tok","expires_in":3600,"refresh_token":"rt-2"}"#
            return (200, Data(body.utf8))
        }
        let token = try await makeService(store: store).validAccessToken()
        XCTAssertEqual(token, "new-tok")
        XCTAssertEqual(store.load()?.refreshToken, "rt-2")
    }

    func testInvalidateAndRefreshFallsBackToAnonymousSignInIfRefreshFails() async throws {
        let store = InMemoryAuthTokenStore(tokens: AuthTokens(
            userId: "u1", accessToken: "old-tok", refreshToken: "stale-rt",
            expiresAt: Date().addingTimeInterval(3600)
        ))
        StubURLProtocol.handler = { request in
            if request.url?.path.hasSuffix("refresh") == true {
                return (401, Data(#"{"error":{"code":"refresh_rejected","message":"x"}}"#.utf8))
            }
            return (200, Data(#"{"user_id":"u2","kind":"anonymous","access_token":"fresh-tok","expires_in":3600,"refresh_token":"rt-3"}"#.utf8))
        }
        let token = try await makeService(store: store).invalidateAndRefresh()
        XCTAssertEqual(token, "fresh-tok")
    }
}
