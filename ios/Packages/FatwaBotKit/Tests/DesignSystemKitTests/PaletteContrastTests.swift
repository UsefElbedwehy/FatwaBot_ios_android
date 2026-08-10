import XCTest
@testable import DesignSystemKit

/// Legibility guards on the bundled palettes.
///
/// ## Why this exists
/// The dark palette shipped with `primary` at #B8514A, which measures 3.88:1 as
/// heading text — under the 4.5:1 body-text bar. Nothing caught it, because the
/// existing token tests assert only that the values are *well-formed hex*, which
/// #B8514A is. A palette can be perfectly well-formed and still be unreadable.
///
/// These tests encode the contrast contract instead of the literal colours, so a
/// future palette change is free to pick any colours it likes as long as the text
/// stays legible.
final class PaletteContrastTests: XCTestCase {

    // MARK: - WCAG 2.1 contrast

    /// Relative luminance, WCAG 2.1 §relativeluminancedef.
    private func luminance(_ hex: String) -> Double {
        let hex = hex.dropFirst() // leading '#'
        let channels = stride(from: 0, to: 6, by: 2).map { offset -> Double in
            let start = hex.index(hex.startIndex, offsetBy: offset)
            let end = hex.index(start, offsetBy: 2)
            let value = Double(UInt8(hex[start..<end], radix: 16) ?? 0) / 255
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]
    }

    /// WCAG contrast ratio, 1.0 (identical) through 21.0 (black on white).
    private func contrast(_ foreground: String, on background: String) -> Double {
        let a = luminance(foreground), b = luminance(background)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    /// 4.5:1 — normal-size body text.
    private static let bodyBar = 4.5
    /// 3:1 — text at 18pt+, or 14pt+ bold. Also the bar for UI component edges.
    private static let largeTextBar = 3.0

    private func assertContrast(
        _ foreground: String, on background: String, atLeast bar: Double,
        _ label: String, file: StaticString = #filePath, line: UInt = #line
    ) {
        let ratio = contrast(foreground, on: background)
        XCTAssertGreaterThanOrEqual(
            ratio, bar,
            String(format: "%@ measures %.2f:1, below the %.1f:1 bar", label, ratio, bar),
            file: file, line: line
        )
    }

    // MARK: - Body text must be comfortably readable in both schemes

    func testBodyTextClearsAA() {
        for (name, tokens) in [
            ("light", DesignTokens.bundledDefault.light),
            ("dark", DesignTokens.bundledDefault.dark),
        ] {
            // Body copy sits on both the page and on cards; both must hold.
            assertContrast(tokens.onSurface, on: tokens.surface,
                           atLeast: Self.bodyBar, "\(name) onSurface/surface")
            assertContrast(tokens.onSurface, on: tokens.surfaceElevated,
                           atLeast: Self.bodyBar, "\(name) onSurface/surfaceElevated")
            // Secondary text is smaller, not larger — it gets the same bar.
            assertContrast(tokens.onSurfaceSecondary, on: tokens.surface,
                           atLeast: Self.bodyBar, "\(name) onSurfaceSecondary/surface")
            assertContrast(tokens.onSurfaceSecondary, on: tokens.surfaceElevated,
                           atLeast: Self.bodyBar, "\(name) onSurfaceSecondary/surfaceElevated")
        }
    }

    /// `primary` is used as heading text (`.foregroundStyle`) as well as a fill.
    ///
    /// The bar here is the large-text one deliberately: on a near-black ground a
    /// single token *cannot* clear 4.5:1 both as text on the surface and under
    /// near-white as a fill — near-white on `primary` at 4.5 caps its luminance
    /// at 0.175, while `primary` on black at 4.5 demands at least 0.202. The
    /// design resolves that by keeping `primary` text large and bold.
    ///
    /// Note what this test does *not* do: the old #B8514A measured 3.48:1 on a
    /// card, so a 3:1 floor would have let it through. This is a guard against
    /// gross failures only. The thing that actually surfaces a marginal palette
    /// is `testDocumentedDarkMeasurementsAreAccurate` below, which forces the
    /// real numbers to be written down where a reviewer sees them.
    func testPrimaryAsTextClearsLargeTextBar() {
        for (name, tokens) in [
            ("light", DesignTokens.bundledDefault.light),
            ("dark", DesignTokens.bundledDefault.dark),
        ] {
            assertContrast(tokens.primary, on: tokens.surface,
                           atLeast: Self.largeTextBar, "\(name) primary-as-text/surface")
            assertContrast(tokens.primary, on: tokens.surfaceElevated,
                           atLeast: Self.largeTextBar, "\(name) primary-as-text/surfaceElevated")
        }
    }

    /// The nav band and the search cap: near-white on a `primary` fill.
    /// Large bold type, so 3:1 — see the note in DesignTokens.swift for why this
    /// cannot be 4.5 at the same time as the test above.
    func testOnPrimaryClearsLargeTextBar() {
        for (name, tokens) in [
            ("light", DesignTokens.bundledDefault.light),
            ("dark", DesignTokens.bundledDefault.dark),
        ] {
            assertContrast(tokens.onPrimary, on: tokens.primary,
                           atLeast: Self.largeTextBar, "\(name) onPrimary/primary")
        }
    }

    /// `accent` is a foreground colour, not decoration — it tints hadith
    /// attributions, dua metadata, streak figures and offline notices via
    /// `.foregroundStyle`. So it needs to survive on the backgrounds it lands on.
    ///
    /// ## Known gap
    /// The light palette's #B8860B measures **2.96:1** on the cream surface and
    /// **2.63:1** on `primaryContainer` — under even the large-text floor. This
    /// is a real legibility defect in light mode, recorded here rather than
    /// quietly excluded so that it is visible and so that this test starts
    /// passing by itself the moment the colour is fixed.
    func testAccentAsTextClearsLargeTextBar() throws {
        XCTExpectFailure(
            "light-mode accent #B8860B is 2.96:1 on surface — pending an owner decision",
            enabled: true
        )
        for (name, tokens) in [
            ("light", DesignTokens.bundledDefault.light),
            ("dark", DesignTokens.bundledDefault.dark),
        ] {
            assertContrast(tokens.accent, on: tokens.surface,
                           atLeast: Self.largeTextBar, "\(name) accent/surface")
            assertContrast(tokens.accent, on: tokens.surfaceElevated,
                           atLeast: Self.largeTextBar, "\(name) accent/surfaceElevated")
        }
    }

    /// Cards are distinguished from the page by their fill, their border, or
    /// both. On a true-black surface the fill step is small by design, so the
    /// outline is carrying the boundary and has to be visible against the card.
    func testCardBoundaryIsPerceptible() {
        for (name, tokens) in [
            ("light", DesignTokens.bundledDefault.light),
            ("dark", DesignTokens.bundledDefault.dark),
        ] {
            let fillStep = contrast(tokens.surfaceElevated, on: tokens.surface)
            let border = contrast(tokens.outline, on: tokens.surfaceElevated)
            XCTAssertGreaterThan(
                max(fillStep, border), 1.15,
                String(
                    format: "%@ card has no visible boundary: fill step %.2f, border %.2f",
                    name, fillStep, border
                )
            )
        }
    }

    /// The reference values behind the comment block in DesignTokens.swift.
    /// Not a duplicate of the bar tests — this one fails loudly if someone edits
    /// the palette without updating the documented measurements, which is how
    /// the comment drifted from reality last time.
    func testDocumentedDarkMeasurementsAreAccurate() {
        let dark = DesignTokens.bundledDefault.dark
        let expected: [(String, Double, String)] = [
            ("onSurface/surface", 21.00, "\(dark.onSurface) on \(dark.surface)"),
            ("primary/surface", 4.78, "\(dark.primary) on \(dark.surface)"),
            ("primary/elevated", 4.26, "\(dark.primary) on \(dark.surfaceElevated)"),
            ("onPrimary/primary", 4.16, "\(dark.onPrimary) on \(dark.primary)"),
            ("accent/surface", 12.78, "\(dark.accent) on \(dark.surface)"),
        ]
        let actual = [
            contrast(dark.onSurface, on: dark.surface),
            contrast(dark.primary, on: dark.surface),
            contrast(dark.primary, on: dark.surfaceElevated),
            contrast(dark.onPrimary, on: dark.primary),
            contrast(dark.accent, on: dark.surface),
        ]
        for (pair, measured) in zip(expected, actual) {
            XCTAssertEqual(
                measured, pair.1, accuracy: 0.01,
                "\(pair.0) (\(pair.2)) is \(String(format: "%.2f", measured)), "
                    + "but DesignTokens.swift documents \(pair.1)"
            )
        }
    }
}
