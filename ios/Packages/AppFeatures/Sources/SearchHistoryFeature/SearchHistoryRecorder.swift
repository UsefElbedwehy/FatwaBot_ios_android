import CoreKit
import Foundation
import NetworkingKit

/// Concrete `SearchHistoryRecording` (CoreKit) — the thing Dua (and any future
/// searchable feature) is injected with. Fire-and-forget: failures are silent
/// (docs/features/search-history.md), never surfaced to the search UI.
public final class SearchHistoryRecorder: SearchHistoryRecording {
    private let client: AuthenticatedAPIClientProtocol

    public init(client: AuthenticatedAPIClientProtocol) {
        self.client = client
    }

    public func record(source: String, queryText: String, locale: String) {
        Task { [client] in
            let _: SearchHistoryEntry? = try? await client.post(
                "v1/search-history",
                body: RecordSearchRequest(source: source, query_text: queryText, locale: locale)
            )
        }
    }
}
