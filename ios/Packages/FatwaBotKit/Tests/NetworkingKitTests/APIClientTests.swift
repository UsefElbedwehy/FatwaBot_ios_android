import XCTest
import CoreKit
@testable import NetworkingKit

final class APIClientTests: XCTestCase {
    private func makeClient() -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return APIClient(
            baseURL: URL(string: "https://example.supabase.co/functions/v1/api")!,
            context: ClientContext(appVersion: "1.0.0", locale: "ar"),
            session: URLSession(configuration: configuration)
        )
    }

    override func tearDown() {
        StubURLProtocol.handler = nil
        super.tearDown()
    }

    func testSendsClientContextHeadersAndDecodes() async throws {
        StubURLProtocol.handler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-client-platform"), "ios")
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-client-version"), "1.0.0")
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-client-locale"), "ar")
            XCTAssertEqual(request.url?.path, "/functions/v1/api/v1/config/theme")
            let body = ##"{"version": 1, "tokens": {"light": {"color.primary": "#7A2A2A"}}}"##
            return (200, Data(body.utf8))
        }
        let theme = try await makeClient().get(Endpoints.theme)
        XCTAssertEqual(theme.version, 1)
    }

    func testQueryParametersAreAppended() async throws {
        StubURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.query, "country=SA")
            let body = #"{"country_code": "SA", "method": "umm_al_qura", "params": {}}"#
            return (200, Data(body.utf8))
        }
        let defaults = try await makeClient().get(Endpoints.prayerDefaults(country: "SA"))
        XCTAssertEqual(defaults.method, "umm_al_qura")
    }

    func testServerErrorSurfacesStructuredCode() async {
        StubURLProtocol.handler = { _ in
            (404, Data(#"{"error": {"code": "no_published_theme", "message": "x"}}"#.utf8))
        }
        do {
            _ = try await makeClient().get(Endpoints.theme)
            XCTFail("expected error")
        } catch let error as APIError {
            XCTAssertEqual(error, .server(statusCode: 404, code: "no_published_theme"))
        } catch {
            XCTFail("unexpected error type: \(error)")
        }
    }
}

final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) -> (Int, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        let (status, data) = handler(request)
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: ["content-type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
