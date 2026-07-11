import XCTest
import NetworkingKit
@testable import SearchHistoryFeature

final class FakeAuthenticatedAPIClient: AuthenticatedAPIClientProtocol, @unchecked Sendable {
    var getHandler: (@Sendable (String, [URLQueryItem]) throws -> Any)?
    var postHandler: (@Sendable (String, Any) throws -> Any)?
    var deleteHandler: (@Sendable (String) throws -> Any)?

    func get<Response: Decodable & Sendable>(_ path: String, query: [URLQueryItem]) async throws -> Response {
        guard let result = try getHandler?(path, query) as? Response else {
            throw APIError.transport("no handler configured")
        }
        return result
    }

    func post<Body: Encodable & Sendable, Response: Decodable & Sendable>(_ path: String, body: Body) async throws -> Response {
        guard let result = try postHandler?(path, body) as? Response else {
            throw APIError.transport("no handler configured")
        }
        return result
    }

    func postEmpty<Response: Decodable & Sendable>(_ path: String) async throws -> Response {
        throw APIError.transport("not used in these tests")
    }

    func patch<Body: Encodable & Sendable, Response: Decodable & Sendable>(_ path: String, body: Body) async throws -> Response {
        throw APIError.transport("not used in these tests")
    }

    func delete<Response: Decodable & Sendable>(_ path: String) async throws -> Response {
        guard let result = try deleteHandler?(path) as? Response else {
            throw APIError.transport("no handler configured")
        }
        return result
    }
}

@MainActor
final class SearchHistoryViewModelTests: XCTestCase {
    private nonisolated static func entry(id: String = "1", queryText: String = "الصلاة", createdAt: Date = Date()) -> SearchHistoryEntry {
        SearchHistoryEntry(id: id, source: "dua", queryText: queryText, locale: "ar", createdAt: createdAt)
    }

    func testLoadPopulatesEntriesFromServer() async {
        let client = FakeAuthenticatedAPIClient()
        client.getHandler = { path, _ in
            XCTAssertEqual(path, "v1/search-history")
            return ListSearchHistoryResponse(entries: [Self.entry()])
        }
        let viewModel = SearchHistoryViewModel(client: client)

        await viewModel.load()

        XCTAssertEqual(viewModel.entries.count, 1)
        XCTAssertNil(viewModel.error)
    }

    func testDeleteRemovesOptimisticallyAndConfirmsWithServer() async {
        let client = FakeAuthenticatedAPIClient()
        let target = Self.entry(id: "1")
        client.getHandler = { _, _ in ListSearchHistoryResponse(entries: [target, Self.entry(id: "2")]) }
        client.deleteHandler = { path in
            XCTAssertEqual(path, "v1/search-history/1")
            return DeletedResponse(deleted: true)
        }
        let viewModel = SearchHistoryViewModel(client: client)
        await viewModel.load()

        await viewModel.delete(target)

        XCTAssertEqual(viewModel.entries.count, 1)
        XCTAssertEqual(viewModel.entries.first?.id, "2")
    }

    func testDeleteRollsBackOnServerFailure() async {
        let client = FakeAuthenticatedAPIClient()
        let target = Self.entry(id: "1")
        client.getHandler = { _, _ in ListSearchHistoryResponse(entries: [target]) }
        client.deleteHandler = { _ in throw APIError.transport("offline") }
        let viewModel = SearchHistoryViewModel(client: client)
        await viewModel.load()

        await viewModel.delete(target)

        XCTAssertEqual(viewModel.entries.count, 1, "a failed delete must restore the optimistically-removed entry")
        XCTAssertNotNil(viewModel.error)
    }

    func testClearAllEmptiesEntriesOnSuccess() async {
        let client = FakeAuthenticatedAPIClient()
        client.getHandler = { _, _ in ListSearchHistoryResponse(entries: [Self.entry()]) }
        client.deleteHandler = { path in
            XCTAssertEqual(path, "v1/search-history")
            return ClearedResponse(cleared: true)
        }
        let viewModel = SearchHistoryViewModel(client: client)
        await viewModel.load()

        await viewModel.clearAll()

        XCTAssertTrue(viewModel.entries.isEmpty)
    }
}
