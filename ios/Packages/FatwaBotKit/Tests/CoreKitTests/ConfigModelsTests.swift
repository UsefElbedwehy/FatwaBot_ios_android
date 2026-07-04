import XCTest
@testable import CoreKit

final class ConfigModelsTests: XCTestCase {
    func testDecodesAggregatedConfigPayload() throws {
        let json = """
        {
          "config": {"hijri.default_offset_days": 0, "leaderboard.display_name_policy": "pseudonymous_default"},
          "flags": {"module.prayer": {"enabled": true, "rollout": {}}, "module.ai_ask": {"enabled": false, "rollout": {}}},
          "locales": [
            {"locale": "ar", "display_name": "العربية", "direction": "rtl", "digits": "eastern"},
            {"locale": "en", "display_name": "English", "direction": "ltr", "digits": "western"}
          ]
        }
        """
        let config = try JSONDecoder().decode(AppConfig.self, from: Data(json.utf8))
        XCTAssertTrue(config.isEnabled("module.prayer"))
        XCTAssertFalse(config.isEnabled("module.ai_ask"))
        XCTAssertFalse(config.isEnabled("module.unknown"), "unknown flags default to disabled")
        XCTAssertEqual(config.locales.first?.direction, "rtl")
        XCTAssertEqual(config.config["hijri.default_offset_days"], .number(0))
    }

    func testHomeLayoutSkipsUnknownSectionTypes() throws {
        let json = """
        {
          "version": 3,
          "sections": [
            {"id": "prayer", "type": "prayer_hero", "props": {}},
            {"id": "future", "type": "hologram_qibla", "props": {"x": 1}},
            {"id": "ask", "type": "ask_ai", "props": {"state": "coming_soon"}}
          ]
        }
        """
        let layout = try JSONDecoder().decode(HomeLayout.self, from: Data(json.utf8))
        let rendered = layout.renderableSections(supported: ["prayer_hero", "ask_ai", "streak_strip"])
        XCTAssertEqual(rendered.map(\.id), ["prayer", "ask"], "unknown section types must be skipped silently")
    }

    func testJSONValueRoundTrip() throws {
        let original: JSONValue = .object([
            "text": .string("سبحان الله"),
            "count": .number(33),
            "enabled": .bool(true),
            "nested": .array([.null, .number(1.5)]),
        ])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
