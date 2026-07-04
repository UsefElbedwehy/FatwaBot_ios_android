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

    static let keyMap: [(WritableKeyPath<ColorTokens, String>, String)] = [
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
        dark: ColorTokens(
            primary: "#D08770",
            primaryContainer: "#3A2422",
            accent: "#D4A73F",
            surface: "#171210",
            surfaceElevated: "#221A17",
            onSurface: "#F1E7E0",
            onSurfaceSecondary: "#B5A398",
            onPrimary: "#2B1B17",
            outline: "#463832"
        ),
        shape: ShapeTokens(cardRadius: 18, controlRadius: 12),
        productName: "Fatwa Bot",
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
