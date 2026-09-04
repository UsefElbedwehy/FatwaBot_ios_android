import DesignSystemKit
import FatwaSearchFeature
import SwiftUI

/// Search-first Home (client redesign, 2026-07-24). Pixel-matches the client
/// mockup (design/homeDesign.jpeg): logo, wordmark, rosette divider, three
/// neumorphic intent cards, an embossed search field, and the manhaj tagline.
/// The cards and the search field open the AI-search flow (M5) — `onOpen`
/// pushes `FatwaSearchScreen` for the tapped mode; RootTabView owns the stack.
struct SearchHomeScreen: View {
    let onOpen: (FatwaSearchMode) -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var tokens: ColorTokens {
        colorScheme == .dark ? DesignTokens.bundledDefault.dark : DesignTokens.bundledDefault.light
    }

    // Declaration order == on-screen order. In the Arabic (RTL) mockup the cards
    // read fatwa · hadith · question from the right, so list them in that order
    // (FatwaSearchMode.allCases is already fatwa, hadith, general).
    private typealias Intent = FatwaSearchMode

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer(minLength: 48)

                // FatwaMark, not a raw `Image("LaunchLogo")`: the asset is a flat
                // maroon raster baked at a fixed color that isn't even one of the
                // brand tokens, so on the dark surface it measured 1.5:1 contrast —
                // present but barely visible. FatwaMark alpha-masks the same
                // artwork and tints it explicitly, so it tracks light/dark like
                // every other brand-mark usage in the app.
                FatwaMark(color: Color(hexToken: tokens.primary))
                    .frame(width: 124, height: 174)
                    .accessibilityHidden(true)

                Text(verbatim: "FATWA")
                    .font(.system(size: 28, weight: .medium, design: .serif))
                    .tracking(3)
                    .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                    .padding(.top, 8)

                divider
                    .padding(.top, 34)
                    .padding(.bottom, 42)

                HStack(spacing: 12) {
                    ForEach(Intent.allCases, id: \.self) { intent in
                        intentCard(intent)
                    }
                }

                searchField
                    .padding(.top, 30)

                HStack(spacing: 8) {
                    RosetteMark(size: 15, color: Color(hexToken: tokens.primary))
                    Text("home.tagline")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Color(hexToken: tokens.primary))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 30)
                .padding(.horizontal, 12)

                Spacer(minLength: 40)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 22)
        }
        .brandScreenBackground(tokens)
    }

    // MARK: - Divider (rosette between two arrow-tipped rules)

    private var divider: some View {
        HStack(spacing: 12) {
            dividerRule(pointsLeft: true)
            RosetteMark(size: 18, color: Color(hexToken: tokens.primary))
            dividerRule(pointsLeft: false)
        }
        .frame(maxWidth: 234)
        .accessibilityHidden(true)
    }

    private func dividerRule(pointsLeft: Bool) -> some View {
        HStack(spacing: 0) {
            if pointsLeft {
                Image(systemName: "arrowtriangle.left.fill")
                    .font(.system(size: 7))
                    .foregroundStyle(Color(hexToken: tokens.primary))
            }
            Rectangle()
                .fill(Color(hexToken: tokens.primary).opacity(0.6))
                .frame(height: 1.2)
            if !pointsLeft {
                Image(systemName: "arrowtriangle.right.fill")
                    .font(.system(size: 7))
                    .foregroundStyle(Color(hexToken: tokens.primary))
            }
        }
    }

    // MARK: - Intent cards (neumorphic cream)

    private func intentCard(_ intent: Intent) -> some View {
        Button { onOpen(intent) } label: {
            VStack(spacing: 12) {
                intentIcon(intent)
                    .frame(height: 26)
                Text(intent.titleKey)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color(hexToken: tokens.onSurface))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 104)
            .padding(.vertical, 10)
            .background(neumorphicSurface(cornerRadius: 24))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func intentIcon(_ intent: Intent) -> some View {
        let color = Color(hexToken: tokens.primary)
        switch intent {
        case .general:
            QuestionBubbleIcon(color: color, size: 23)
        case .hadith:
            Image(systemName: "book.fill")
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(color)
        case .fatwa:
            Image(systemName: "magnifyingglass")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(color)
                .scaleEffect(x: -1, y: 1)   // handle to bottom-left, matching the mockup
        }
    }

    // MARK: - Search field (embossed pill, maroon leading cap)

    private var searchField: some View {
        Button { onOpen(.general) } label: {
            HStack(spacing: 0) {
                HStack {
                    Text("home.search_placeholder")
                        .font(.subheadline)
                        .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                    Spacer()
                }
                .padding(.horizontal, 18)
                ZStack {
                    Color(hexToken: tokens.primary)
                    Image(systemName: "magnifyingglass")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color(hexToken: tokens.onPrimary))
                }
                .frame(width: 60)
            }
            .frame(height: 54)
            .background(neumorphicSurface(cornerRadius: 18))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            // Pinned LTR so the maroon cap stays on the right in Arabic too —
            // it is a fixed part of the control, not a leading/trailing affordance.
            .environment(\.layoutDirection, .leftToRight)
        }
        .buttonStyle(.plain)
    }

    /// Cream-on-cream neumorphism: soft drop shadow + a light top-left highlight.
    ///
    /// Both halves have to flip for dark mode. The fill uses `surface` in light
    /// (cream card on the cream wash) but `surfaceElevated` in dark — in the dark
    /// palette `surface` IS the page background, so a card filled with it would
    /// be invisible. And the highlight can't be white: a white glow on a dark
    /// card reads as a rendering artefact, so it becomes a faint lift instead.
    private func neumorphicSurface(cornerRadius: CGFloat) -> some View {
        let isDark = colorScheme == .dark
        return RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color(hexToken: isDark ? tokens.surfaceElevated : tokens.surface))
            .shadow(
                color: Color.black.opacity(isDark ? 0.35 : 0.05),
                radius: 9, x: 3, y: 5
            )
            .shadow(
                color: (isDark ? Color.white.opacity(0.05) : Color.white.opacity(0.7)),
                radius: 6, x: -4, y: -4
            )
    }
}

/// Round chat-bubble outline with a small down-left tail and a centered "?",
/// matching the mockup's question glyph (no exact SF Symbol equivalent).
struct QuestionBubbleIcon: View {
    let color: Color
    var size: CGFloat = 28

    var body: some View {
        Canvas { ctx, sz in
            let w = sz.width, h = sz.height
            let lw = w * 0.09
            let dia = w * 0.80
            let r = dia / 2
            let cxC = w * 0.56              // nudge right to leave room for the tail
            let cyC = r + lw / 2
            let circleRect = CGRect(x: cxC - r, y: cyC - r, width: dia, height: dia)

            // Tail: a small triangle hanging off the circle's lower-left edge.
            let a = CGPoint(x: cxC - r * 0.72, y: cyC + r * 0.70)
            let b = CGPoint(x: cxC - r * 0.30, y: cyC + r * 0.95)
            let tip = CGPoint(x: cxC - r * 1.02, y: h - lw * 0.5)
            var tail = Path()
            tail.move(to: a)
            tail.addLine(to: tip)
            tail.addLine(to: b)
            tail.closeSubpath()
            ctx.fill(tail, with: .color(color))

            // Bubble ring, then the "?".
            ctx.stroke(Path(ellipseIn: circleRect), with: .color(color), lineWidth: lw)
            let q = Text("?").font(.system(size: dia * 0.56, weight: .bold)).foregroundColor(color)
            ctx.draw(q, at: CGPoint(x: cxC, y: cyC))
        }
        .frame(width: size, height: size)
    }
}

/// Eight-petal geometric rosette (khatam-style flower) used on the divider and
/// the tagline — a small brand motif matching the mockup.
struct RosetteMark: View {
    var size: CGFloat = 20
    var color: Color

    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                Ellipse()
                    .fill(color)
                    .frame(width: size * 0.26, height: size * 0.62)
                    .offset(y: -size * 0.2)
                    .rotationEffect(.degrees(Double(i) * 45))
            }
            Circle()
                .fill(color)
                .frame(width: size * 0.26, height: size * 0.26)
        }
        .frame(width: size, height: size)
    }
}
