import DesignSystemKit
import SwiftUI

/// Search-first Home (client redesign, 2026-07-24). Pixel-matches the FATWA BOT
/// mockup (design/homeDesign.jpeg): logo, wordmark, rosette divider, three
/// neumorphic intent cards, an embossed search field, and the manhaj tagline.
/// The fatwa/hadith/question search is the M5 AI-search surface (on hold) — the
/// cards and the search field open a branded "coming soon" sheet for now.
struct SearchHomeScreen: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var showComingSoon = false

    private var tokens: ColorTokens {
        colorScheme == .dark ? DesignTokens.bundledDefault.dark : DesignTokens.bundledDefault.light
    }

    // Declaration order == on-screen order. In the Arabic (RTL) mockup the cards
    // read fatwa · hadith · question from the right, so list them in that order.
    private enum Intent: String, Identifiable, CaseIterable {
        case fatwa, hadith, question
        var id: String { rawValue }
        var titleKey: LocalizedStringKey {
            switch self {
            case .question: return "home.card.question"
            case .hadith: return "home.card.hadith"
            case .fatwa: return "home.card.fatwa"
            }
        }
        var icon: String {
            switch self {
            case .question: return "questionmark.circle"
            case .hadith: return "book.fill"
            case .fatwa: return "magnifyingglass"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer(minLength: 48)

                Image("LaunchLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 94, height: 132)
                    .accessibilityHidden(true)

                Text(verbatim: "FATWA BOT")
                    .font(.system(size: 28, weight: .medium, design: .serif))
                    .tracking(3)
                    .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                    .padding(.top, 4)

                divider
                    .padding(.top, 26)
                    .padding(.bottom, 32)

                HStack(spacing: 12) {
                    ForEach(Intent.allCases) { intent in
                        intentCard(intent)
                    }
                }

                searchField
                    .padding(.top, 16)

                HStack(spacing: 8) {
                    RosetteMark(size: 15, color: Color(hexToken: tokens.accent))
                    Text("home.tagline")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Color(hexToken: tokens.primary))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 18)
                .padding(.horizontal, 12)

                Spacer(minLength: 40)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 22)
        }
        .brandScreenBackground(tokens)
        .sheet(isPresented: $showComingSoon) {
            ComingSoonSheet(tokens: tokens)
                .presentationDetents([.medium])
        }
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
        Button { showComingSoon = true } label: {
            VStack(spacing: 12) {
                Image(systemName: intent.icon)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(Color(hexToken: tokens.primary))
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

    // MARK: - Search field (embossed pill, maroon leading cap)

    private var searchField: some View {
        Button { showComingSoon = true } label: {
            HStack(spacing: 0) {
                ZStack {
                    Color(hexToken: tokens.primary)
                    Image(systemName: "magnifyingglass")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color(hexToken: tokens.onPrimary))
                }
                .frame(width: 60)
                HStack {
                    Text("home.search_placeholder")
                        .font(.subheadline)
                        .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                    Spacer()
                }
                .padding(.horizontal, 18)
            }
            .frame(height: 54)
            .background(neumorphicSurface(cornerRadius: 18))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            // Mockup keeps the maroon magnifier cap on the left in both languages.
            .environment(\.layoutDirection, .leftToRight)
        }
        .buttonStyle(.plain)
    }

    /// Cream-on-cream neumorphism: soft dark drop + light top highlight, no border.
    private func neumorphicSurface(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color(hexToken: tokens.surface))
            .shadow(color: Color(hexToken: tokens.onSurface).opacity(0.09), radius: 11, x: 4, y: 8)
            .shadow(color: .white.opacity(0.85), radius: 7, x: -5, y: -5)
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

/// Branded "coming soon" sheet for the AI-search surface (M5, on hold).
struct ComingSoonSheet: View {
    let tokens: ColorTokens

    var body: some View {
        VStack(spacing: 16) {
            ArchIconBadge(systemImage: "sparkles", tokens: tokens)
            Text("home.coming_soon.title")
                .font(.title3.weight(.bold))
                .foregroundStyle(Color(hexToken: tokens.onSurface))
            Text("home.coming_soon.body")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .brandScreenBackground(tokens)
    }
}
