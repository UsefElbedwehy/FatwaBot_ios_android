import CoreKit
import Foundation
import NetworkingKit
import Observation

/// State machine for the Leaderboards screen (docs/features/leaderboard.md).
/// A single generic renderer drives every board — no per-scope/per-period
/// client code; unknown scope/period values just render generically.
@MainActor
@Observable
public final class LeaderboardViewModel {
    public private(set) var boards: [LeaderboardBoard] = []
    public private(set) var isLoading = false
    public private(set) var error: String?

    private let client: AuthenticatedAPIClientProtocol
    private let haptics: HapticsProviding
    private let region: RegionResolving

    public init(
        client: AuthenticatedAPIClientProtocol,
        haptics: HapticsProviding = NoopHaptics(),
        region: RegionResolving = UnknownRegionResolver()
    ) {
        self.client = client
        self.haptics = haptics
        self.region = region
    }

    public func load() async {
        isLoading = true
        error = nil
        do {
            let response: ListBoardsResponse = try await client.get("v1/leaderboards", query: [])
            boards = response.boards
        } catch {
            self.error = error.userFacingMessage
        }
        isLoading = false
    }

    /// Optimistically flips `joined` locally so the UI reacts immediately;
    /// a subsequent `load()` reconciles with the server's authoritative state.
    /// - Parameter city: an explicit choice from the UI. When nil, a regional
    ///   board derives one from the prayer-times location rather than failing —
    ///   the user has already told the app where they are.
    public func join(key: String, publishName: Bool, city: String? = nil) async {
        let scope = boards.first { $0.key == key }?.scope ?? "global"
        let isRegional = scope == "city" || scope == "country"
        // Only geocode for a board that needs it. A global join must not
        // trigger a location lookup the user gets nothing from.
        let resolved = isRegional ? await region.currentRegion() : .unknown
        do {
            let _: LeaderboardMembership = try await client.post(
                "v1/leaderboards/\(key)/join",
                body: JoinLeaderboardRequest(
                    publish_name: publishName,
                    city: scope == "city" ? (city ?? resolved.city) : nil,
                    country: scope == "country" ? resolved.countryCode : nil
                )
            )
            haptics.targetReached()
            await load()
        } catch {
            self.error = error.userFacingMessage
        }
    }

    public func leave(key: String) async {
        do {
            let _: LeftResponse = try await client.postEmpty("v1/leaderboards/\(key)/leave")
            await load()
        } catch {
            self.error = error.userFacingMessage
        }
    }
}

// internal (not private) so tests can construct it via @testable import.
struct LeftResponse: Decodable {
    let left: Bool
}
