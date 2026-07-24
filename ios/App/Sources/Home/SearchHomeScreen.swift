import DesignSystemKit
import SwiftUI

/// Search-first Home (client redesign, 2026-07-24). Matches the FATWA BOT
/// mockup: logo, wordmark, divider, three intent cards, a search field, and the
/// manhaj tagline. The fatwa/hadith/question search is the M5 AI-search surface,
/// which is on hold — so the cards and the search field open a branded
/// "coming soon" sheet for now.
struct SearchHomeScreen: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var showComingSoon = false

    private var tokens: ColorTokens {
        colorScheme == .dark ? DesignTokens.bundledDefault.dark : DesignTokens.bundledDefault.light
    }

    private enum Intent: String, Identifiable, CaseIterable {
        case question, hadith, fatwa
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
            case .question: return "questionmark.bubble.fill"
            case .hadith: return "book.fill"
            case .fatwa: return "text.magnifyingglass"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer(minLength: 24)

                Image("LaunchLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .accessibilityHidden(true)

                Text(verbatim: "FATWA BOT")
                    .font(.system(size: 34, weight: .semibold, design: .serif))
                    .tracking(4)
                    .foregroundStyle(Color(hexToken: tokens.onSurface))
                    .padding(.top, 8)

                divider
                    .padding(.vertical, 28)

                HStack(spacing: 12) {
                    ForEach(Intent.allCases) { intent in
                        intentCard(intent)
                    }
                }
                .padding(.horizontal, 4)

                searchField
                    .padding(.top, 26)

                HStack(spacing: 8) {
                    Image(systemName: "staroflife.fill")
                        .font(.caption2)
                        .foregroundStyle(Color(hexToken: tokens.accent))
                    Text("home.tagline")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Color(hexToken: tokens.primary))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 22)
                .padding(.horizontal, 12)

                Spacer(minLength: 40)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
        }
        .brandScreenBackground(tokens)
        .sheet(isPresented: $showComingSoon) {
            ComingSoonSheet(tokens: tokens)
                .presentationDetents([.medium])
        }
    }

    private var divider: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color(hexToken: tokens.primary).opacity(0.5))
                .frame(height: 1)
            Image(systemName: "staroflife")
                .font(.subheadline)
                .foregroundStyle(Color(hexToken: tokens.primary))
            Rectangle()
                .fill(Color(hexToken: tokens.primary).opacity(0.5))
                .frame(height: 1)
        }
    }

    private func intentCard(_ intent: Intent) -> some View {
        Button { showComingSoon = true } label: {
            VStack(spacing: 12) {
                Image(systemName: intent.icon)
                    .font(.title2)
                    .foregroundStyle(Color(hexToken: tokens.primary))
                Text(intent.titleKey)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color(hexToken: tokens.onSurface))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 118)
            .padding(.vertical, 10)
            .background(Color(hexToken: tokens.surfaceElevated), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color(hexToken: tokens.primary).opacity(0.08), lineWidth: 1)
            )
            .shadow(color: Color(hexToken: tokens.primary).opacity(0.06), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    private var searchField: some View {
        Button { showComingSoon = true } label: {
            HStack(spacing: 0) {
                ZStack {
                    Color(hexToken: tokens.primary)
                    Image(systemName: "magnifyingglass")
                        .font(.headline)
                        .foregroundStyle(Color(hexToken: tokens.onPrimary))
                }
                .frame(width: 64)
                HStack {
                    Text("home.search_placeholder")
                        .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                    Spacer()
                }
                .padding(.horizontal, 16)
            }
            .frame(height: 56)
            .background(Color(hexToken: tokens.surfaceElevated))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color(hexToken: tokens.primary).opacity(0.10), lineWidth: 1))
            .shadow(color: Color(hexToken: tokens.primary).opacity(0.08), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
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
