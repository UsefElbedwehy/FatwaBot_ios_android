import CoreKit
import Foundation
import NetworkingKit
import Observation

/// Kill switch for the whole AI-search flow, independent of what the backend
/// would actually return. Search is fully built and already degrades to the
/// "coming soon" framing on its own when the provider keys aren't configured
/// (503 `ai_unavailable`) — this flag existed for the separate, non-technical
/// reason that the OCR corpus's copyright/licensing basis isn't resolved yet.
///
/// Enabled for testing now that both provider keys are configured. This is
/// still safe with an unresolved corpus: retrieval enforces
/// `license_status = 'granted'` in SQL (`0042_fatwa_schema.sql`), and nothing
/// ingested pre-pause has ever been flipped to `'granted'` — so search will
/// refuse ("couldn't find a vetted source") rather than surface any
/// copyrighted content, regardless of this flag.
public enum FatwaSearchFeatureFlags {
    public static let searchEnabled = true
}

/// State machine for the AI fatwa-search flow (`POST /v1/search`,
/// docs/features/ai-search-m5.0-spec.md §App wiring).
@MainActor
@Observable
public final class FatwaSearchViewModel {
    public enum Phase: Equatable {
        case idle
        case loading
        /// 503 `ai_unavailable` — the AI stack isn't configured yet. Distinct
        /// from `.error` so the UI can show the same "coming soon" framing the
        /// Home cards already use, rather than an alarming failure state for
        /// something that is expected right now.
        case unavailable
        case error(String)
        case result(SearchResponse)
    }

    public let mode: FatwaSearchMode
    public var question: String
    public private(set) var phase: Phase = .idle

    private let client: AuthenticatedAPIClientProtocol
    private let searchEnabled: Bool

    public init(
        mode: FatwaSearchMode,
        client: AuthenticatedAPIClientProtocol,
        initialQuestion: String = "",
        searchEnabled: Bool = FatwaSearchFeatureFlags.searchEnabled
    ) {
        self.mode = mode
        self.client = client
        self.question = initialQuestion
        self.searchEnabled = searchEnabled
    }

    public func submit() async {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard searchEnabled else {
            phase = .unavailable
            return
        }
        phase = .loading
        do {
            let response: SearchResponse = try await client.post(
                "v1/search",
                body: SearchRequestBody(question: trimmed, mode: mode.rawValue)
            )
            phase = .result(response)
        } catch let apiError as APIError {
            if case .server(503, "ai_unavailable") = apiError {
                phase = .unavailable
            } else {
                phase = .error(apiError.userFacingMessage)
            }
        } catch {
            phase = .error(error.userFacingMessage)
        }
    }

    /// Back to a blank ask — used by "ask again" after a result or refusal.
    public func reset() {
        question = ""
        phase = .idle
    }
}
