import CoreKit
import Foundation
import NetworkingKit
import Observation

/// State machine for the Search History screen (docs/features/search-history.md).
@MainActor
@Observable
public final class SearchHistoryViewModel {
    public private(set) var entries: [SearchHistoryEntry] = []
    public private(set) var isLoading = false
    public private(set) var error: String?

    private let client: AuthenticatedAPIClientProtocol
    private let haptics: HapticsProviding

    public init(client: AuthenticatedAPIClientProtocol, haptics: HapticsProviding = NoopHaptics()) {
        self.client = client
        self.haptics = haptics
    }

    public func load() async {
        isLoading = true
        error = nil
        do {
            let response: ListSearchHistoryResponse = try await client.get("v1/search-history", query: [])
            entries = response.entries
        } catch {
            self.error = error.userFacingMessage
        }
        isLoading = false
    }

    public func delete(_ entry: SearchHistoryEntry) async {
        let previous = entries
        entries.removeAll { $0.id == entry.id }
        haptics.tick()
        do {
            let _: DeletedResponse = try await client.delete("v1/search-history/\(entry.id)")
        } catch {
            entries = previous
            self.error = error.userFacingMessage
        }
    }

    /// Caller must confirm first — this is destructive (spec §"never records...").
    public func clearAll() async {
        let previous = entries
        entries = []
        haptics.tick()
        do {
            let _: ClearedResponse = try await client.delete("v1/search-history")
        } catch {
            entries = previous
            self.error = error.userFacingMessage
        }
    }
}

// internal (not private) so tests can construct them via @testable import.
struct DeletedResponse: Decodable {
    let deleted: Bool
}

struct ClearedResponse: Decodable {
    let cleared: Bool
}
