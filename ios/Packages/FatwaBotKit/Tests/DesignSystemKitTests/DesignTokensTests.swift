import XCTest
import CoreKit
@testable import DesignSystemKit

final class DesignTokensTests: XCTestCase {
    func testServerThemeOverlaysKnownTokens() {
        let server = ServerTheme(
            version: 7,
            tokens: [
                "light": .object(["color.primary": .string("#112233")]),
                "dark": .object(["color.accent": .string("#445566")]),
                "shape": .object(["radius.card": .number(24)]),
                "product_name": .string("Companion"),
            ]
        )
        let resolved = DesignTokens.bundledDefault.applying(serverTheme: server)
        XCTAssertEqual(resolved.themeVersion, 7)
        XCTAssertEqual(resolved.light.primary, "#112233")
        XCTAssertEqual(resolved.dark.accent, "#445566")
        XCTAssertEqual(resolved.shape.cardRadius, 24)
        XCTAssertEqual(resolved.productName, "Companion")
        // Untouched values keep bundled defaults.
        XCTAssertEqual(resolved.light.accent, DesignTokens.bundledDefault.light.accent)
        XCTAssertEqual(resolved.dark.primary, DesignTokens.bundledDefault.dark.primary)
    }

    func testMalformedValuesAreIgnored() {
        let server = ServerTheme(
            version: 2,
            tokens: [
                "light": .object([
                    "color.primary": .string("not-a-color"),
                    "color.mystery_token": .string("#FFFFFF"),
                ]),
                "product_name": .string(""),
            ]
        )
        let resolved = DesignTokens.bundledDefault.applying(serverTheme: server)
        XCTAssertEqual(resolved.light.primary, DesignTokens.bundledDefault.light.primary)
        XCTAssertEqual(resolved.productName, "Fatwa")
    }

    func testBundledPaletteIsWellFormed() {
        for tokens in [DesignTokens.bundledDefault.light, DesignTokens.bundledDefault.dark] {
            for (keyPath, key) in ColorTokens.keyMap {
                XCTAssertTrue(
                    ColorTokens.isValidHex(tokens[keyPath: keyPath]),
                    "invalid default for \(key)"
                )
            }
        }
    }
}
