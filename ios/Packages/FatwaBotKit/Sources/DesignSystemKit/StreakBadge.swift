import SwiftUI

/// Renders the brand mark, preferring the real artwork when one is bundled.
///
/// ## Why an asset slot rather than a traced path
/// The supplied logo is a raster export. A brand mark has to stay crisp from a
/// 16pt accessory glyph up to a large widget, so it wants to be a vector — and
/// hand-tracing a raster yields something *close to* the mark, which is worse
/// than either the real artwork or an honest stand-in.
///
/// So: if an image asset named ``FatwaMark/assetName`` exists in the main
/// bundle, that is used. Otherwise it falls back to ``MihrabArchShape``, the
/// arch the rest of the app already draws. Dropping the real vector in under
/// that name is the whole swap — no call site changes.
public struct FatwaMark: View {
    /// Drop a vector (PDF/SVG) asset under this name in the app's asset catalog
    /// and every streak badge, widget and launcher picks it up automatically.
    public static let assetName = "BrandMark"

    private let color: Color

    public init(color: Color) {
        self.color = color
    }

    private var hasAsset: Bool {
        #if canImport(UIKit)
        UIImage(named: Self.assetName) != nil
        #else
        false
        #endif
    }

    public var body: some View {
        if hasAsset {
            Image(Self.assetName)
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(color)
        } else {
            MihrabArchShape()
                .fill(color)
                .aspectRatio(0.78, contentMode: .fit)
        }
    }
}

// MARK: - Flame

/// The streak flame. Asymmetric on purpose — a symmetric teardrop reads as a
/// balloon; the lean and the notched left shoulder are what make it read as fire
/// at 20pt.
public struct StreakFlameShape: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let tip = CGPoint(x: rect.minX + w * 0.52, y: rect.minY)

        path.move(to: tip)
        // Right flank: swings wide, then tucks under the base.
        path.addCurve(
            to: CGPoint(x: rect.minX + w * 0.98, y: rect.minY + h * 0.62),
            control1: CGPoint(x: rect.minX + w * 0.70, y: rect.minY + h * 0.20),
            control2: CGPoint(x: rect.minX + w * 0.98, y: rect.minY + h * 0.34)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + w * 0.50, y: rect.maxY),
            control1: CGPoint(x: rect.minX + w * 0.98, y: rect.minY + h * 0.86),
            control2: CGPoint(x: rect.minX + w * 0.79, y: rect.maxY)
        )
        // Left flank back up.
        path.addCurve(
            to: CGPoint(x: rect.minX + w * 0.03, y: rect.minY + h * 0.60),
            control1: CGPoint(x: rect.minX + w * 0.21, y: rect.maxY),
            control2: CGPoint(x: rect.minX + w * 0.02, y: rect.minY + h * 0.85)
        )
        // The notch — the kink that separates fire from teardrop.
        path.addCurve(
            to: CGPoint(x: rect.minX + w * 0.34, y: rect.minY + h * 0.30),
            control1: CGPoint(x: rect.minX + w * 0.04, y: rect.minY + h * 0.42),
            control2: CGPoint(x: rect.minX + w * 0.30, y: rect.minY + h * 0.46)
        )
        path.addCurve(
            to: tip,
            control1: CGPoint(x: rect.minX + w * 0.38, y: rect.minY + h * 0.16),
            control2: CGPoint(x: rect.minX + w * 0.44, y: rect.minY + h * 0.10)
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - Badge

/// Flame + brand mark + count, the way a streak reads at a glance.
///
/// The count sits *below* the flame rather than inside it. Inside looks tighter
/// in a mockup, but the mark already occupies the flame's optical centre, and a
/// three-digit streak (which is the streak worth being proud of) has nowhere to
/// go — it either shrinks to unreadable or collides with the mark.
public struct StreakBadge: View {
    public enum Size {
        case small, medium, large

        var flameHeight: CGFloat {
            switch self {
            case .small: 34
            case .medium: 56
            case .large: 88
            }
        }

        var countFont: Font {
            switch self {
            case .small: .system(size: 15, weight: .bold, design: .rounded)
            case .medium: .system(size: 24, weight: .bold, design: .rounded)
            case .large: .system(size: 40, weight: .heavy, design: .rounded)
            }
        }
    }

    private let count: Int
    private let size: Size
    private let isActive: Bool
    private let tokens: ColorTokens

    /// - Parameter isActive: whether the streak is still alive today. A cold
    ///   flame is how a lapsed streak should look — greying the number alone
    ///   reads as "loading", not "you lost it".
    public init(count: Int, size: Size = .medium, isActive: Bool = true, tokens: ColorTokens) {
        self.count = count
        self.size = size
        self.isActive = isActive
        self.tokens = tokens
    }

    private var flameGradient: LinearGradient {
        let colors: [Color] = isActive
            ? [Color(hexToken: tokens.accent), Color(hexToken: tokens.primary)]
            : [Color(hexToken: tokens.onSurfaceSecondary).opacity(0.45),
               Color(hexToken: tokens.onSurfaceSecondary).opacity(0.28)]
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }

    public var body: some View {
        VStack(spacing: size == .large ? 6 : 3) {
            ZStack {
                StreakFlameShape()
                    .fill(flameGradient)
                    .aspectRatio(0.82, contentMode: .fit)
                    .frame(height: size.flameHeight)
                // The mark sits low in the flame, where the body is widest —
                // centring it in the bounding box would push it into the taper.
                FatwaMark(color: Color(hexToken: tokens.onPrimary))
                    .frame(height: size.flameHeight * 0.40)
                .offset(y: size.flameHeight * 0.12)
            }
            Text("\(count)")
                .font(size.countFont)
                .monospacedDigit()
                .foregroundStyle(
                    Color(hexToken: isActive ? tokens.primary : tokens.onSurfaceSecondary)
                )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("streak.badge.accessibility \(count)"))
    }
}
