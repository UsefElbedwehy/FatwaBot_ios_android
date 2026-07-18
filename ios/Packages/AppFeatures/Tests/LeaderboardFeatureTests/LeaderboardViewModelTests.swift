import XCTest
import NetworkingKit
@testable import LeaderboardFeature

final class FakeAuthenticatedAPIClient: AuthenticatedAPIClientProtocol, @unchecked Sendable {
    var getHandler: (@Sendable (String, [URLQueryItem]) throws -> Any)?
    var postHandler: (@Sendable (String, Any) throws -> Any)?
    var postEmptyHandler: (@Sendable (String) throws -> Any)?
    private(set) var lastPostBody: Any?
    private(set) var lastPostPath: String?
    private(set) var getCallCount = 0

    func get<Response: Decodable & Sendable>(_ path: String, query: [URLQueryItem]) async throws -> Response {
        getCallCount += 1
        guard let result = try getHandler?(path, query) as? Response else {
            throw APIError.transport("no handler configured")
        }
        return result
    }

    func post<Body: Encodable & Sendable, Response: Decodable & Sendable>(_ path: String, body: Body) async throws -> Response {
        lastPostPath = path
        lastPostBody = body
        guard let result = try postHandler?(path, body) as? Response else {
            throw APIError.transport("no handler configured")
        }
        return result
    }

    func postEmpty<Response: Decodable & Sendable>(_ path: String) async throws -> Response {
        guard let result = try postEmptyHandler?(path) as? Response else {
            throw APIError.transport("no handler configured")
        }
        return result
    }

    func patch<Body: Encodable & Sendable, Response: Decodable & Sendable>(_ path: String, body: Body) async throws -> Response {
        throw APIError.transport("not used in these tests")
    }

    func delete<Response: Decodable & Sendable>(_ path: String) async throws -> Response {
        throw APIError.transport("not used in these tests")
    }
}

@MainActor
final class LeaderboardViewModelTests: XCTestCase {
    private nonisolated static func board(key: String = "weekly_fajr", joined: Bool = false, myRank: Int? = nil) -> LeaderboardBoard {
        LeaderboardBoard(
            key: key, name: "Weekly Fajr", scope: "global", period: "weekly",
            joined: joined, myRank: myRank,
            entries: [LeaderboardEntry(rank: 1, score: 42, displayName: "anon_123")]
        )
    }

    func testLoadPopulatesBoardsFromServer() async {
        let client = FakeAuthenticatedAPIClient()
        client.getHandler = { path, _ in
            XCTAssertEqual(path, "v1/leaderboards")
            return ListBoardsResponse(boards: [Self.board(joined: true, myRank: 1)])
        }
        let viewModel = LeaderboardViewModel(client: client)

        await viewModel.load()

        XCTAssertEqual(viewModel.boards.count, 1)
        XCTAssertTrue(viewModel.boards[0].joined)
        XCTAssertEqual(viewModel.boards[0].myRank, 1)
        XCTAssertNil(viewModel.error)
    }

    func testLoadSurfacesErrorOnFailure() async {
        let client = FakeAuthenticatedAPIClient()
        client.getHandler = { _, _ in throw APIError.server(statusCode: 401, code: "unauthorized") }
        let viewModel = LeaderboardViewModel(client: client)

        await viewModel.load()

        XCTAssertNotNil(viewModel.error)
        XCTAssertTrue(viewModel.boards.isEmpty)
    }

    func testJoinPostsRequestThenReloads() async {
        let client = FakeAuthenticatedAPIClient()
        client.postHandler = { path, _ in
            XCTAssertEqual(path, "v1/leaderboards/weekly_fajr/join")
            return LeaderboardMembership(handle: "anon_456", publishName: false, city: nil)
        }
        client.getHandler = { _, _ in ListBoardsResponse(boards: [Self.board(joined: true, myRank: 3)]) }
        let viewModel = LeaderboardViewModel(client: client)

        await viewModel.join(key: "weekly_fajr", publishName: false, city: nil)

        XCTAssertEqual(client.getCallCount, 1, "joining must reload boards to reflect authoritative server state")
        XCTAssertTrue(viewModel.boards[0].joined)
    }

    func testLeavePostsToLeaveEndpointThenReloads() async {
        let client = FakeAuthenticatedAPIClient()
        client.postEmptyHandler = { path in
            XCTAssertEqual(path, "v1/leaderboards/weekly_fajr/leave")
            return LeftResponse(left: true)
        }
        client.getHandler = { _, _ in ListBoardsResponse(boards: [Self.board(joined: false)]) }
        let viewModel = LeaderboardViewModel(client: client)

        await viewModel.leave(key: "weekly_fajr")

        XCTAssertFalse(viewModel.boards[0].joined)
    }
}
