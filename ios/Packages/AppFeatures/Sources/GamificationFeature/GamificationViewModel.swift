import CoreKit
import Foundation
import NetworkingKit
import Observation

/// State machine for the Gamification screen (docs/features/gamification.md).
/// Renders server descriptors verbatim — no client-side scoring/streak math.
@MainActor
@Observable
public final class GamificationViewModel {
    public private(set) var profile: GamificationProfile = .empty
    public private(set) var isLoading = false
    public private(set) var error: String?

    private let client: AuthenticatedAPIClientProtocol
    private let recorder: GamificationEventRecorder?
    private let timezone: String

    public init(
        client: AuthenticatedAPIClientProtocol,
        recorder: GamificationEventRecorder? = nil,
        timezone: String = TimeZone.current.identifier
    ) {
        self.client = client
        self.recorder = recorder
        self.timezone = timezone
    }

    public func load() async {
        isLoading = true
        error = nil
        // Flush any queued events first so a fresh profile reflects them.
        await recorder?.flush()
        do {
            profile = try await client.get(
                "v1/gamification/profile",
                query: [URLQueryItem(name: "timezone", value: timezone)]
            )
        } catch {
            self.error = String(describing: error)
        }
        isLoading = false
    }
}
