import CoreKit
import Foundation

/// Semantic token set for one color scheme. The token *schema* is fixed and native
/// (ADR-0011); the server overrides *values* via /v1/config/theme. Bundled defaults
/// (DefaultTheme.json — mirrors backend/supabase/seed.sql) are the offline fallback.
public struct ColorTokens: Equatable, Sendable {
    public var primary: String
    public var primaryContainer: String
    public var accent: String
    public var surface: String
    public var surfaceElevated: String
    public var onSurface: String
    public var onSurfaceSecondary: String
    public var onPrimary: String
    public var outline: String

    nonisolated(unsafe) static let keyMap: [(WritableKeyPath<ColorTokens, String>, String)] = [
        (\.primary, "color.primary"),
        (\.primaryContainer, "color.primary_container"),
        (\.accent, "color.accent"),
        (\.surface, "color.surface"),
        (\.surfaceElevated, "color.surface_elevated"),
        (\.onSurface, "color.on_surface"),
        (\.onSurfaceSecondary, "color.on_surface_secondary"),
        (\.onPrimary, "color.on_primary"),
        (\.outline, "color.outline"),
    ]

    /// Overlays any recognized server values; unknown keys are ignored, missing keys keep defaults.
    func overlaying(_ values: [String: JSONValue]) -> ColorTokens {
        var result = self
        for (keyPath, key) in Self.keyMap {
            if let hex = values[key]?.stringValue, Self.isValidHex(hex) {
                result[keyPath: keyPath] = hex
            }
        }
        return result
    }

    static func isValidHex(_ value: String) -> Bool {
        value.count == 7 && value.hasPrefix("#") && value.dropFirst().allSatisfy(\.isHexDigit)
    }
}

public struct ShapeTokens: Equatable, Sendable {
    public var cardRadius: Double
    public var controlRadius: Double
}

/// Shared animation durations (M4 polish pass) — quickDuration for small
/// value changes (counters, progress bars), standardDuration for
/// screen/section-level transitions (empty-state swaps, list changes).
/// Not server-overridable (unlike color/shape) since motion isn't part of
/// the ADR-0011 theme payload; bundled-only.
public enum MotionTokens {
    public static let quickDuration: Double = 0.2
    public static let standardDuration: Double = 0.3
}

public struct DesignTokens: Equatable, Sendable {
    public var light: ColorTokens
    public var dark: ColorTokens
    public var shape: ShapeTokens
    public var productName: String
    public var themeVersion: Int

    /// Bundled fallback — values mirror the server seed so online/offline first paint is identical.
    public static let bundledDefault = DesignTokens(
        light: ColorTokens(
            primary: "#7A2A2A",
            primaryContainer: "#F3E4E1",
            accent: "#B8860B",
            surface: "#FAF3EC",
            surfaceElevated: "#FFFFFF",
            onSurface: "#2B1B17",
            onSurfaceSecondary: "#6E5A54",
            onPrimary: "#FFFFFF",
            outline: "#E3D5CC"
        ),
        // Dark palette — "True Night", chosen by the owner from a rendered
        // comparison of five candidates.
        //
        // ## The constraint that shapes every value here
        // `primary` does two jobs at once: it fills large surfaces (the nav
        // band, the search cap) AND is used as a foreground for headings and
        // icons. Those two jobs pull in opposite directions, and on a near-black
        // ground they cannot *both* clear 4.5:1 with one token — near-white on
        // `primary` at 4.5 caps its relative luminance at 0.175, while `primary`
        // as text on a black surface at 4.5 demands at least 0.202. No colour
        // satisfies both.
        //
        // The resolution is that the nav band is large bold type, where the WCAG
        // bar is 3:1, not 4.5:1. So `primary` is tuned for the harder job — body
        // sized heading text — and the fill rides on the large-text allowance.
        // The practical rule that falls out: **never put small text on a
        // `primary` fill.** Use `primaryContainer` for that.
        //
        // ## Measured
        //   onSurface on surface        21.00:1  (pure white on pure black)
        //   primary as text on surface   4.78:1  (was 3.88 — the old value failed)
        //   primary as text on elevated  4.26:1  ← the number that actually
        //       governs. Headings sit on *cards*, not on the black background,
        //       and a card is `surfaceElevated`. It clears the 3:1 large-bold bar
        //       but not 4.5, so a `primary` heading must stay large and bold.
        //       Lifting `primary` far enough to clear 4.5 here would need
        //       roughly a 7% luminance increase, which visibly shifts the
        //       chosen colour — deliberately not done.
        //   onPrimary on primary         4.16:1  (large bold only; bar is 3:1)
        //   accent on surface           12.78:1
        //
        // The previous #B8514A missed the 4.5 heading bar. Before that, #D08770
        // was a washed-out salmon tuned only for the foreground job — it read as
        // a different brand once it filled the nav band, and forced `onPrimary`
        // to be *dark*, which is backwards for a fill colour.
        //
        // ## Known trade-off
        // `surface` is true #000000 for OLED. That leaves only one elevation
        // step (`surfaceElevated`, ΔL* 5.5) and no third level, so nested rows
        // inside a card rely on `outline` rather than their own fill. Graded
        // alternatives with a full three-level ladder were built and rejected in
        // favour of this one; if nesting ever needs to go deeper, that decision
        // is the thing to revisit, not these values.
        dark: ColorTokens(
            primary: "#C4564B",
            primaryContainer: "#351F1C",
            accent: "#EFC46B",
            surface: "#000000",
            surfaceElevated: "#16110F",
            onSurface: "#FFFFFF",
            onSurfaceSecondary: "#C4B3A9",
            onPrimary: "#FFF7F5",
            outline: "#2A2320"
        ),
        shape: ShapeTokens(cardRadius: 18, controlRadius: 12),
        productName: "Fatwa",
        themeVersion: 0
    )

    /// Applies a server theme (ADR-0011 layer 2). Robust to partial payloads:
    /// anything unrecognized or malformed silently keeps its default.
    public func applying(serverTheme: ServerTheme) -> DesignTokens {
        var result = self
        result.themeVersion = serverTheme.version
        if let values = serverTheme.tokens["light"]?.objectValue {
            result.light = result.light.overlaying(values)
        }
        if let values = serverTheme.tokens["dark"]?.objectValue {
            result.dark = result.dark.overlaying(values)
        }
        if let shape = serverTheme.tokens["shape"]?.objectValue {
            if let radius = shape["radius.card"]?.numberValue { result.shape.cardRadius = radius }
            if let radius = shape["radius.control"]?.numberValue { result.shape.controlRadius = radius }
        }
        if let name = serverTheme.tokens["product_name"]?.stringValue, !name.isEmpty {
            result.productName = name
        }
        return result
    }
}
