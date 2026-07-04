import XCTest
import ConfigKit
import CoreKit
import NetworkingKit
@testable import HomeFeature

final class HomeViewModelTests: XCTestCase {
    final class StubStore: ConfigStoring, @unchecked Sendable {
        var snapshot: ConfigSnapshot?
        init(_ snapshot: ConfigSnapshot?) { self.snapshot = snapshot }
        func load() -> ConfigSnapshot? { snapshot }
        func save(_ new: ConfigSnapshot) { snapshot = new }
    }

    struct FailingClient: APIClientProtocol {
        func get<Response: Decodable & Sendable>(_ endpoint: Endpoint<Response>) async throws -> Response {
            throw APIError.transport("offline")
        }
    }

    @MainActor
    func testFallbackLayoutRendersWhenNoServerLayoutCached() async {
        let config = ConfigService(store: StubStore(nil), client: FailingClient())
        let viewModel = HomeViewModel(config: config, appVersion: "0.1.0")
        await viewModel.load()
        XCTAssertEqual(
            viewModel.sections.map(\.type),
            ["ambient_header", "prayer_hero", "ask_ai", "quick_actions"]
        )
        XCTAssertFalse(viewModel.askEnabled)
    }

    @MainActor
    func testServerLayoutOrderWinsAndUnknownTypesAreSkipped() async {
        let layout = HomeLayout(version: 9, sections: [
            .init(id: "ask", type: "ask_ai", props: [:]),
            .init(id: "future", type: "content_card", props: [:]), // not in catalog v1
            .init(id: "prayer", type: "prayer_hero", props: [:]),
        ])
        let snapshot = ConfigSnapshot(homeLayout: layout, fetchedAt: .init(timeIntervalSince1970: 0))
        let config = ConfigService(store: StubStore(snapshot), client: FailingClient())
        let viewModel = HomeViewModel(config: config, appVersion: "0.1.0")
        await viewModel.load()
        XCTAssertEqual(viewModel.sections.map(\.id), ["ask", "prayer"], "server order wins; unknown skipped")
    }
}
