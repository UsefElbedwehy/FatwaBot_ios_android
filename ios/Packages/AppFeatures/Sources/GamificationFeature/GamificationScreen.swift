import DesignSystemKit
import SwiftUI

public struct GamificationScreen: View {
    @State private var viewModel: GamificationViewModel
    @Environment(\.colorScheme) private var colorScheme

    public init(viewModel: GamificationViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    private var tokens: ColorTokens {
        let base = DesignTokens.bundledDefault
        return colorScheme == .dark ? base.dark : base.light
    }

    private var isEmpty: Bool {
        !viewModel.isLoading && viewModel.profile == .empty && viewModel.error == nil
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if let error = viewModel.error {
                    InlineNoticeCard(text: error, tokens: tokens)
                }

                if let headline = viewModel.profile.streaks.max(by: { $0.currentLength < $1.currentLength }),
                   headline.currentLength > 0 {
                    StreakHeroCard(streak: headline, tokens: tokens)
                }

                if !viewModel.profile.streaks.isEmpty {
                    Section2(header: "gamification.streaks_section", icon: "calendar", tokens: tokens) {
                        VStack(spacing: 12) {
                            ForEach(viewModel.profile.streaks) { streak in
                                StreakCard(streak: streak, tokens: tokens)
                            }
                        }
                    }
                }

                if isEmpty {
                    BrandEmptyState(systemImage: "moon.stars.fill", messageKey: "gamification.empty_state", tokens: tokens)
                }
            }
            .padding(20)
        }
        .brandScreenBackground(tokens)
        .overlay {
            if viewModel.isLoading && viewModel.profile == .empty {
                ProgressView().tint(Color(hexToken: tokens.primary))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .navigationTitle(Text("gamification.title"))
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }
}

/// Small section scaffold: branded header + content, kept local so the feature
/// package doesn't need a shared wrapper.
private struct Section2<Content: View>: View {
    let header: LocalizedStringKey
    let icon: String
    let tokens: ColorTokens
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            BrandSectionHeader(header, systemImage: icon, tokens: tokens)
            content
        }
    }
}

private struct InlineNoticeCard: View {
    let text: String
    let tokens: ColorTokens

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "wifi.exclamationmark")
                .foregroundStyle(Color(hexToken: tokens.accent))
            Text(text)
                .font(.footnote)
                .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
        }
        .brandCard(tokens)
    }
}

/// Hero card highlighting the strongest active streak — big number in a ring.
private struct StreakHeroCard: View {
    let streak: GamificationStreak
    let tokens: ColorTokens

    var body: some View {
        HStack(spacing: 18) {
            // Flame + brand mark + count (owner decision, 2026-07). The ring this
            // replaced encoded current/longest as a fraction, which reads as
            // "progress toward a goal" — a streak has no goal, and a user at
            // their personal best saw a full ring that never moved again.
            StreakBadge(
                count: streak.currentLength,
                size: .large,
                isActive: streak.currentLength > 0,
                tokens: tokens
            )
            .frame(width: 96)

            VStack(alignment: .leading, spacing: 6) {
                Text(streak.name)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color(hexToken: tokens.onSurface))
                Text("gamification.longest \(streak.longestLength)")
                    .font(.subheadline)
                    .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                if streak.graceRemaining > 0 {
                    Label("gamification.grace_remaining \(streak.graceRemaining)", systemImage: "heart.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color(hexToken: tokens.accent))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color(hexToken: tokens.primaryContainer), Color(hexToken: tokens.surfaceElevated)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color(hexToken: tokens.primary).opacity(0.15), lineWidth: 1)
        )
        .shadow(color: Color(hexToken: tokens.primary).opacity(0.10), radius: 16, x: 0, y: 8)
        .accessibilityElement(children: .combine)
    }
}

private struct StreakCard: View {
    let streak: GamificationStreak
    let tokens: ColorTokens

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color(hexToken: tokens.primaryContainer))
                // The app's own mark, not a hand-drawn arch. `FatwaMark` uses
                // the bundled logo asset and falls back to the drawn shape only
                // when that asset is missing, so this is the logo wherever it
                // ships and never a blank circle.
                FatwaMark(color: Color(hexToken: tokens.primary))
                    .frame(height: 22)
            }
            .frame(width: 44, height: 44)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(streak.name).font(.body.weight(.semibold))
                    .foregroundStyle(Color(hexToken: tokens.onSurface))
                if streak.graceRemaining > 0 {
                    Text("gamification.grace_remaining \(streak.graceRemaining)")
                        .font(.caption)
                        .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(streak.currentLength)")
                    .font(.title2.weight(.bold).monospacedDigit())
                    .foregroundStyle(Color(hexToken: tokens.primary))
                Text("gamification.longest \(streak.longestLength)")
                    .font(.caption2)
                    .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
            }
        }
        .brandCard(tokens)
        .accessibilityElement(children: .combine)
    }
}
