import CoreKit
import Foundation
import NetworkingKit
import Observation

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

    public init(mode: FatwaSearchMode, client: AuthenticatedAPIClientProtocol, initialQuestion: String = "") {
        self.mode = mode
        self.client = client
        self.question = initialQuestion
    }

    public func submit() async {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
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
