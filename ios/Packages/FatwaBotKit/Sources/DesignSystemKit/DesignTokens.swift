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
        // Dark palette notes — `primary` has to do two jobs at once: it fills
        // large surfaces (the nav band, the search cap) AND is used as a
        // foreground for headings and icons. The old #D08770 was tuned only for
        // the second job: a washed-out salmon that read as a different brand
        // once it filled the nav band, and it forced `onPrimary` to be *dark*,
        // which is backwards for a fill colour.
        //
        // #B8514A is a lifted brick that still reads as the maroon family: dark
        // enough that near-white sits on it legibly, light enough to carry as a
        // heading against the near-black surface. Surfaces gained a clearer
        // elevation delta (a 3-point luminance step was invisible), and the gold
        // accent was brightened, since #B8860B is nearly black on a dark ground.
        dark: ColorTokens(
            primary: "#B8514A",
            primaryContainer: "#3B2320",
            accent: "#E0B457",
            surface: "#14100F",
            surfaceElevated: "#221B19",
            onSurface: "#F5EBE4",
            onSurfaceSecondary: "#BCA79C",
            onPrimary: "#FFF6F1",
            outline: "#3E312D"
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
