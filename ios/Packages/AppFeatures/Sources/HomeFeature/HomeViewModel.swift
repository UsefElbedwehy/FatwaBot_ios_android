import ConfigKit
import CoreKit
import Foundation
import Observation

/// Renders the server-composed Home layout through the native section catalog
/// (ADR-0011). Unknown section types are dropped here — never an error.
@MainActor
@Observable
public final class HomeViewModel {
    /// Section catalog v1 — the native components this app version can render.
    public static let supportedSections: Set<String> = [
        "ambient_header", "prayer_hero", "ask_ai", "quick_actions",
    ]

    public private(set) var sections: [HomeLayout.Section] = []
    public private(set) var askEnabled = false

    private let config: ConfigService
    private let appVersion: String

    public init(config: ConfigService, appVersion: String) {
        self.config = config
        self.appVersion = appVersion
    }

    /// Bundled default layout — mirrors backend seed; used until a server
    /// layout is cached (ADR-0011: bundled defaults are offline fallbacks).
    static let fallbackLayout = HomeLayout(version: 0, sections: [
        .init(id: "header", type: "ambient_header", props: [:]),
        .init(id: "prayer", type: "prayer_hero", props: ["show_timeline": .bool(true)]),
        .init(id: "ask", type: "ask_ai", props: ["state": .string("coming_soon")]),
        .init(id: "quick", type: "quick_actions", props: [:]),
    ])

    public func load() async {
        let layout = await config.current.homeLayout ?? Self.fallbackLayout
        sections = layout.renderableSections(supported: Self.supportedSections)
        askEnabled = await config.isEnabled("module.ai_ask", appVersion: appVersion)
    }

    public func refresh(locales: [String]) async {
        await config.refresh(locales: locales)
        await load()
    }
}
