import XCTest
import NetworkingKit
@testable import LeaderboardFeature

final class FakeAuthenticatedAPIClient: AuthenticatedAPIClientProtocol, @unchecked Sendable {
    var getHandler: (@Sendable (String, [URLQueryItem]) throws -> Any)?
    var postHandler: (@Sendable (String, Any) throws -> Any)?
    /// Encoded request bodies, so a test can assert on what actually went over
    /// the wire rather than on state the caller could have set either way.
    private(set) var postedBodies: [String] = []
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
        postedBodies.append(
            (try? JSONEncoder().encode(body)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
        )
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

    // MARK: - Region is derived, never typed

    nonisolated private static func regionalBoard(scope: String, key: String) -> LeaderboardBoard {
        LeaderboardBoard(
            key: key, name: "board", scope: scope, period: "weekly",
            joined: false, myRank: nil, entries: []
        )
    }

    func testJoiningACityBoardSendsTheDerivedCityWithoutBeingTold() async {
        // The join sheet no longer has a text field: it passes nil and the view
        // model fills the city in from the prayer-times location. If that link
        // breaks, a city join silently posts no city and the user lands on a
        // board nobody else is on.
        let client = FakeAuthenticatedAPIClient()
        client.getHandler = { _, _ in
            ListBoardsResponse(boards: [Self.regionalBoard(scope: "city", key: "consistency_city")])
        }
        client.postHandler = { _, _ in
            LeaderboardMembership(handle: "anon", publishName: false, city: "الرياض")
        }
        let viewModel = LeaderboardViewModel(
            client: client,
            region: ClosureRegionResolver { LeaderboardRegion(city: "الرياض", countryCode: "SA") }
        )
        await viewModel.load()

        await viewModel.join(key: "consistency_city", publishName: false, city: nil)

        XCTAssertTrue(
            client.postedBodies.contains { $0.contains("الرياض") },
            "a city join must carry the derived city"
        )
    }

    func testJoiningACountryBoardSendsTheDerivedCountryCode() async {
        let client = FakeAuthenticatedAPIClient()
        client.getHandler = { _, _ in
            ListBoardsResponse(boards: [Self.regionalBoard(scope: "country", key: "consistency_country")])
        }
        client.postHandler = { _, _ in
            LeaderboardMembership(handle: "anon", publishName: false, city: nil)
        }
        let viewModel = LeaderboardViewModel(
            client: client,
            region: ClosureRegionResolver { LeaderboardRegion(city: "الرياض", countryCode: "SA") }
        )
        await viewModel.load()

        await viewModel.join(key: "consistency_country", publishName: false, city: nil)

        XCTAssertTrue(client.postedBodies.contains { $0.contains("\"SA\"") })
    }

    func testAGlobalJoinCarriesNoRegionAtAll() async {
        // A global board must not leak the user's city or country — there is no
        // reason for the server to receive it, and sending it anyway is the kind
        // of quiet over-collection nobody notices.
        let client = FakeAuthenticatedAPIClient()
        client.getHandler = { _, _ in
            ListBoardsResponse(boards: [Self.regionalBoard(scope: "global", key: "consistency_global")])
        }
        client.postHandler = { _, _ in
            LeaderboardMembership(handle: "anon", publishName: false, city: nil)
        }
        let viewModel = LeaderboardViewModel(
            client: client,
            region: ClosureRegionResolver { LeaderboardRegion(city: "الرياض", countryCode: "SA") }
        )
        await viewModel.load()

        await viewModel.join(key: "consistency_global", publishName: false, city: nil)

        XCTAssertFalse(client.postedBodies.contains { $0.contains("الرياض") })
        XCTAssertFalse(client.postedBodies.contains { $0.contains("\"SA\"") })
    }
}
