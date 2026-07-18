import SwiftUI

/// The brand's signature motif (docs/05_DESIGN_DIRECTION.md §2, docs/06_DESIGN_REVIEW.md):
/// a pointed mihrab/mosque-window arch, used sparingly as a decorative
/// backdrop for icons and dividers — not yet implemented anywhere until now.
public struct MihrabArchShape: Shape {
    /// Fraction of the shape's height devoted to the pointed arch curve
    /// (the remainder is the straight jamb down to the base).
    private let archRatio: CGFloat

    public init(archRatio: CGFloat = 0.55) {
        self.archRatio = archRatio
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let curveHeight = rect.height * archRatio
        let springY = rect.minY + (rect.height - curveHeight)
        let apex = CGPoint(x: rect.midX, y: rect.minY)
        let springLeft = CGPoint(x: rect.minX, y: springY)
        let springRight = CGPoint(x: rect.maxX, y: springY)
        let controlLeft = CGPoint(x: rect.minX, y: springY - curveHeight * 0.85)
        let controlRight = CGPoint(x: rect.maxX, y: springY - curveHeight * 0.85)

        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: springLeft)
        path.addQuadCurve(to: apex, control: controlLeft)
        path.addQuadCurve(to: springRight, control: controlRight)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// A branded icon badge — an SF Symbol centered inside a filled+stroked
/// `MihrabArchShape`, replacing bare floating icons on onboarding/empty-state
/// surfaces with the app's actual brand motif.
public struct ArchIconBadge: View {
    private let systemImage: String
    private let tokens: ColorTokens
    private let size: CGSize

    public init(systemImage: String, tokens: ColorTokens, size: CGSize = CGSize(width: 92, height: 104)) {
        self.systemImage = systemImage
        self.tokens = tokens
        self.size = size
    }

    public var body: some View {
        ZStack {
            MihrabArchShape()
                .fill(Color(hexToken: tokens.primaryContainer))
            MihrabArchShape()
                .stroke(Color(hexToken: tokens.primary), lineWidth: 2)
            Image(systemName: systemImage)
                .font(.system(size: size.width * 0.32, weight: .medium))
                .foregroundStyle(Color(hexToken: tokens.primary))
                .padding(.top, size.height * 0.12)
        }
        .frame(width: size.width, height: size.height)
        .accessibilityHidden(true)
    }
}
