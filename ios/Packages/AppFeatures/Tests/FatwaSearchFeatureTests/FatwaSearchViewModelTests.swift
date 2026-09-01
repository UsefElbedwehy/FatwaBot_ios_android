import XCTest
import NetworkingKit
@testable import FatwaSearchFeature

final class FakeSearchClient: AuthenticatedAPIClientProtocol, @unchecked Sendable {
    var postHandler: (@Sendable (String, Any) throws -> Any)?

    func get<Response: Decodable & Sendable>(_ path: String, query: [URLQueryItem]) async throws -> Response {
        throw APIError.transport("not used in these tests")
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
        throw APIError.transport("not used in these tests")
    }
}

@MainActor
final class FatwaSearchViewModelTests: XCTestCase {
    func testSubmitDoesNothingOnBlankQuestion() async {
        let client = FakeSearchClient()
        client.postHandler = { _, _ in XCTFail("should not call the network for a blank question"); return SearchResponse(answer: "", citations: [], refused: false, mode: "general") }
        let viewModel = FatwaSearchViewModel(mode: .general, client: client, initialQuestion: "   ")

        await viewModel.submit()

        XCTAssertEqual(viewModel.phase, .idle)
    }

    func testSubmitGoesStraightToUnavailableWithoutANetworkCallWhenSearchIsDisabled() async {
        let client = FakeSearchClient()
        client.postHandler = { _, _ in XCTFail("must not call the network while search is disabled"); return SearchResponse(answer: "", citations: [], refused: false, mode: "general") }
        let viewModel = FatwaSearchViewModel(mode: .fatwa, client: client, initialQuestion: "سؤال", searchEnabled: false)

        await viewModel.submit()

        XCTAssertEqual(viewModel.phase, .unavailable)
    }

    func testSubmitPostsTheTrimmedQuestionAndModeAndPopulatesTheResult() async {
        let client = FakeSearchClient()
        client.postHandler = { path, body in
            XCTAssertEqual(path, "v1/search")
            let request = try XCTUnwrap(body as? SearchRequestBody)
            XCTAssertEqual(request.question, "ما حكم كذا")
            XCTAssertEqual(request.mode, "fatwa")
            return SearchResponse(
                answer: "الجواب: ...",
                citations: [
                    SearchCitation(
                        chunkId: "c1", scholar: "ابن عثيمين", sourceTitle: "فتاوى أركان الإسلام",
                        pageNumber: 12, videoTimestamp: nil, quotedText: "نص الاقتباس"
                    ),
                ],
                refused: false,
                mode: "fatwa"
            )
        }
        let viewModel = FatwaSearchViewModel(mode: .fatwa, client: client, initialQuestion: "  ما حكم كذا  ", searchEnabled: true)

        await viewModel.submit()

        guard case .result(let response) = viewModel.phase else {
            return XCTFail("expected a result phase, got \(viewModel.phase)")
        }
        XCTAssertEqual(response.citations.count, 1)
        XCTAssertFalse(response.refused)
    }

    func testSubmitMapsA503AiUnavailableToTheUnavailablePhase() async {
        let client = FakeSearchClient()
        client.postHandler = { _, _ in throw APIError.server(statusCode: 503, code: "ai_unavailable") }
        let viewModel = FatwaSearchViewModel(mode: .hadith, client: client, initialQuestion: "سؤال", searchEnabled: true)

        await viewModel.submit()

        XCTAssertEqual(viewModel.phase, .unavailable)
    }

    func testSubmitMapsOtherFailuresToAGenericErrorPhase() async {
        let client = FakeSearchClient()
        client.postHandler = { _, _ in throw APIError.transport("offline") }
        let viewModel = FatwaSearchViewModel(mode: .general, client: client, initialQuestion: "سؤال", searchEnabled: true)

        await viewModel.submit()

        guard case .error = viewModel.phase else {
            return XCTFail("expected an error phase, got \(viewModel.phase)")
        }
    }

    func testResetClearsTheQuestionAndReturnsToIdle() async {
        let client = FakeSearchClient()
        client.postHandler = { _, _ in
            SearchResponse(answer: "جواب", citations: [], refused: false, mode: "general")
        }
        let viewModel = FatwaSearchViewModel(mode: .general, client: client, initialQuestion: "سؤال", searchEnabled: true)
        await viewModel.submit()

        viewModel.reset()

        XCTAssertEqual(viewModel.phase, .idle)
        XCTAssertEqual(viewModel.question, "")
    }

    func testARefusedResultStillPopulatesTheAnswerMessageWithNoCitations() async {
        let client = FakeSearchClient()
        client.postHandler = { _, _ in
            SearchResponse(answer: "لم نجد في مصادرنا الموثوقة ما يجيب عن هذا السؤال.", citations: [], refused: true, mode: "general")
        }
        let viewModel = FatwaSearchViewModel(mode: .general, client: client, initialQuestion: "سؤال بلا مصدر", searchEnabled: true)

        await viewModel.submit()

        guard case .result(let response) = viewModel.phase else {
            return XCTFail("expected a result phase, got \(viewModel.phase)")
        }
        XCTAssertTrue(response.refused)
        XCTAssertTrue(response.citations.isEmpty)
        XCTAssertFalse(response.answer.isEmpty)
    }
}
