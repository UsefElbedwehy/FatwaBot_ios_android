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

    /// Regression test for a real bug: `validAccessToken()` used to read
    /// `cached` and call `refresh(using:)` independently per caller. Since
    /// actors are reentrant at `await` points, two callers racing while the
    /// token is expired would both fire `/v1/auth/refresh` with the same
    /// (single-use) refresh token — the backend replay-rejects the second,
    /// whose `try?` swallowed that and silently signed in a fresh anonymous
    /// identity instead, dropping the session. Both callers must now share
    /// one in-flight refresh and land on the same token.
    func testConcurrentCallsWithAnExpiredTokenShareOneRefresh() async throws {
        let store = InMemoryAuthTokenStore(tokens: AuthTokens(
            userId: "u1", accessToken: "old-tok", refreshToken: "rt-1",
            expiresAt: Date().addingTimeInterval(10) // inside the 60s buffer
        ))
        let refreshCalls = CallCounter()
        StubURLProtocol.handler = { request in
            if request.url?.path.hasSuffix("refresh") == true {
                refreshCalls.increment()
            }
            let body = #"{"user_id":"u1","kind":"anonymous","access_token":"new-tok","expires_in":3600,"refresh_token":"rt-2"}"#
            return (200, Data(body.utf8))
        }
        let service = makeService(store: store)
        async let first = service.validAccessToken()
        async let second = service.validAccessToken()
        let (tokenA, tokenB) = try await (first, second)

        XCTAssertEqual(tokenA, "new-tok")
        XCTAssertEqual(tokenB, "new-tok")
        XCTAssertEqual(refreshCalls.count, 1, "both callers should have shared one /v1/auth/refresh call")
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

/// Thread-safe counter for asserting how many times a `StubURLProtocol`
/// handler ran — the handler is a plain synchronous closure, invoked from
/// whatever thread `URLSession` schedules it on, so a bare `var` would race.
private final class CallCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    func increment() {
        lock.lock()
        value += 1
        lock.unlock()
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}
