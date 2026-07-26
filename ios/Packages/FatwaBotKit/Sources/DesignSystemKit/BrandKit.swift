import SwiftUI

/// Premium, token-driven building blocks that give every screen the branded
/// "warm cream + elevated maroon-accented card" language from
/// docs/05_DESIGN_DIRECTION.md — replacing bare system `List`/`Form` chrome
/// (stakeholder direction, 2026-07-11: screens must not look like stock UIKit).
///
/// All components are theme-token driven (never hard-coded colors) so the
/// ADR-0011 server theme overlay keeps working.

// MARK: - Screen background

private struct BrandScreenBackground: ViewModifier {
    let tokens: ColorTokens

    func body(content: Content) -> some View {
        content.background(
            ZStack {
                // Warm vertical wash so the surface isn't a flat fill: cream at
                // the top easing into the faintly-warmer primary container tint.
                LinearGradient(
                    colors: [
                        Color(hexToken: tokens.surface),
                        Color(hexToken: tokens.primaryContainer).opacity(0.35),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                // Soft corner glow instead of a clipped arch silhouette. Any
                // hard-edged shape bled into the corner reads as a stray
                // square/rectangle (its straight jambs and flat base stay
                // on-screen while the curve goes off it) — rotating it wasn't
                // enough. A radial gradient has no edges at all, so it can only
                // ever read as brand warmth.
                RadialGradient(
                    colors: [
                        Color(hexToken: tokens.primary).opacity(0.07),
                        Color(hexToken: tokens.primary).opacity(0.0),
                    ],
                    center: .topTrailing,
                    startRadius: 0,
                    endRadius: 420
                )
                .allowsHitTesting(false)
            }
            .ignoresSafeArea()
        )
    }
}

public extension View {
    /// Branded screen background: warm cream wash + a faint mihrab-arch
    /// watermark. Use on the root of a `ScrollView`-based screen.
    func brandScreenBackground(_ tokens: ColorTokens) -> some View {
        modifier(BrandScreenBackground(tokens: tokens))
    }
}

// MARK: - Card

/// Elevated rounded card — the primary content container. Soft shadow + a
/// hairline outline give real depth instead of flat inset-grouped rows.
public struct BrandCard<Content: View>: View {
    private let tokens: ColorTokens
    private let padding: CGFloat
    private let content: Content

    public init(_ tokens: ColorTokens, padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.tokens = tokens
        self.padding = padding
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hexToken: tokens.surfaceElevated), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color(hexToken: tokens.outline).opacity(0.6), lineWidth: 1)
            )
            .shadow(color: Color(hexToken: tokens.primary).opacity(0.06), radius: 12, x: 0, y: 6)
    }
}

public extension View {
    /// Wrap any view in the branded elevated-card treatment.
    func brandCard(_ tokens: ColorTokens, padding: CGFloat = 16) -> some View {
        BrandCard(tokens, padding: padding) { self }
    }
}

// MARK: - Section header

/// A premium section header: a short maroon accent bar + title, with an
/// optional trailing accessory — replaces stock `Section("…")` headers.
public struct BrandSectionHeader<Trailing: View>: View {
    private let titleKey: LocalizedStringKey
    private let systemImage: String?
    private let tokens: ColorTokens
    private let trailing: Trailing

    public init(
        _ titleKey: LocalizedStringKey,
        systemImage: String? = nil,
        tokens: ColorTokens,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.titleKey = titleKey
        self.systemImage = systemImage
        self.tokens = tokens
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(
                    LinearGradient(
                        colors: [Color(hexToken: tokens.primary), Color(hexToken: tokens.accent)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(width: 4, height: 18)
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(hexToken: tokens.primary))
            }
            Text(titleKey)
                .font(.title3.weight(.bold))
                .foregroundStyle(Color(hexToken: tokens.onSurface))
            Spacer(minLength: 8)
            trailing
        }
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Ring progress

/// Circular progress ring (missions, streaks, session counters). Foreground is
/// a maroon→gold sweep; the track is a faint primary.
public struct RingProgress: View {
    private let value: Double
    private let lineWidth: CGFloat
    private let tokens: ColorTokens

    public init(value: Double, lineWidth: CGFloat = 8, tokens: ColorTokens) {
        self.value = max(0, min(1, value))
        self.lineWidth = lineWidth
        self.tokens = tokens
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(Color(hexToken: tokens.primary).opacity(0.14), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: value)
                .stroke(
                    AngularGradient(
                        colors: [Color(hexToken: tokens.primary), Color(hexToken: tokens.accent), Color(hexToken: tokens.primary)],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
    }
}

// MARK: - Rank medal

/// Leaderboard rank badge — gold/silver/bronze disc for the top three, a plain
/// numbered chip otherwise.
public struct RankMedal: View {
    private let rank: Int
    private let tokens: ColorTokens

    public init(rank: Int, tokens: ColorTokens) {
        self.rank = rank
        self.tokens = tokens
    }

    private var medalColors: [Color]? {
        switch rank {
        case 1: return [Color(red: 0.85, green: 0.68, blue: 0.30), Color(red: 0.72, green: 0.53, blue: 0.16)]
        case 2: return [Color(red: 0.78, green: 0.78, blue: 0.80), Color(red: 0.60, green: 0.60, blue: 0.63)]
        case 3: return [Color(red: 0.80, green: 0.55, blue: 0.35), Color(red: 0.62, green: 0.40, blue: 0.24)]
        default: return nil
        }
    }

    public var body: some View {
        ZStack {
            if let medalColors {
                Circle().fill(LinearGradient(colors: medalColors, startPoint: .top, endPoint: .bottom))
                Text("\(rank)")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(.white)
            } else {
                Circle().fill(Color(hexToken: tokens.primaryContainer))
                Text("\(rank)")
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(Color(hexToken: tokens.primary))
            }
        }
        .frame(width: 34, height: 34)
    }
}

// MARK: - Empty state

/// Consistent branded empty state: arch-badged icon + message.
public struct BrandEmptyState: View {
    private let systemImage: String
    private let messageKey: LocalizedStringKey
    private let tokens: ColorTokens

    public init(systemImage: String, messageKey: LocalizedStringKey, tokens: ColorTokens) {
        self.systemImage = systemImage
        self.messageKey = messageKey
        self.tokens = tokens
    }

    public var body: some View {
        VStack(spacing: 16) {
            ArchIconBadge(systemImage: systemImage, tokens: tokens, size: CGSize(width: 74, height: 84))
            Text(messageKey)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
        .padding(.horizontal, 24)
    }
}

// MARK: - Info notice

/// Soft informational banner — an ⓘ glyph beside a short passage, used to carry
/// a study/advisory note above a screen's content.
///
/// The copy is deliberately NOT baked in: callers pass a resolved string so it can
/// come from the server string pack (ADR-0011) and be changed without a release.
/// Rendered in brand tones rather than the system blue so it reads as part of the
/// app instead of an OS alert.
public struct InfoNotice: View {
    private let text: String
    private let tokens: ColorTokens

    public init(_ text: String, tokens: ColorTokens) {
        self.text = text
        self.tokens = tokens
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 17))
                .foregroundStyle(Color(hexToken: tokens.primary))
                .accessibilityHidden(true)
            Text(text)
                .font(.footnote)
                .foregroundStyle(Color(hexToken: tokens.onSurface))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            Color(hexToken: tokens.primaryContainer).opacity(0.55),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(hexToken: tokens.primary).opacity(0.14), lineWidth: 1)
        )
    }
}
