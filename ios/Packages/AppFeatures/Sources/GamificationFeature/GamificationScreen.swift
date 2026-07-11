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
                    Section2(header: "gamification.streaks_section", icon: "flame.fill", tokens: tokens) {
                        VStack(spacing: 12) {
                            ForEach(viewModel.profile.streaks) { streak in
                                StreakCard(streak: streak, tokens: tokens)
                            }
                        }
                    }
                }

                if !viewModel.profile.missions.isEmpty {
                    Section2(header: "gamification.missions_section", icon: "target", tokens: tokens) {
                        VStack(spacing: 12) {
                            ForEach(viewModel.profile.missions) { mission in
                                MissionCard(mission: mission, tokens: tokens)
                            }
                        }
                    }
                }

                if !viewModel.profile.badges.isEmpty {
                    Section2(header: "gamification.badges_section", icon: "rosette", tokens: tokens) {
                        BadgeGrid(badges: viewModel.profile.badges, tokens: tokens)
                    }
                }

                if isEmpty {
                    BrandEmptyState(systemImage: "flame", messageKey: "gamification.empty_state", tokens: tokens)
                }
            }
            .padding(20)
        }
        .brandScreenBackground(tokens)
        .overlay {
            if viewModel.isLoading && viewModel.profile == .empty {
                ProgressView().tint(Color(hexToken: tokens.primary))
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
            ZStack {
                RingProgress(
                    value: streak.longestLength > 0 ? Double(streak.currentLength) / Double(max(streak.longestLength, streak.currentLength)) : 1,
                    lineWidth: 9,
                    tokens: tokens
                )
                VStack(spacing: 0) {
                    Text("\(streak.currentLength)")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Color(hexToken: tokens.primary))
                    Image(systemName: "flame.fill")
                        .font(.caption)
                        .foregroundStyle(Color(hexToken: tokens.accent))
                }
            }
            .frame(width: 96, height: 96)

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
                Image(systemName: "flame.fill")
                    .font(.title3)
                    .foregroundStyle(Color(hexToken: tokens.primary))
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

private struct MissionCard: View {
    let mission: GamificationMission
    let tokens: ColorTokens

    private var progressFraction: Double {
        mission.target > 0 ? Double(mission.progress) / Double(mission.target) : 0
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RingProgress(value: progressFraction, lineWidth: 6, tokens: tokens)
                    .motionAnimation(.easeOut(duration: MotionTokens.standardDuration), value: progressFraction)
                Text("\(Int(min(progressFraction, 1) * 100))%")
                    .font(.caption2.weight(.bold).monospacedDigit())
                    .foregroundStyle(Color(hexToken: tokens.primary))
            }
            .frame(width: 48, height: 48)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(mission.name).font(.body.weight(.semibold))
                    .foregroundStyle(Color(hexToken: tokens.onSurface))
                Text("\(mission.progress)/\(mission.target)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
            }
            Spacer(minLength: 0)
        }
        .brandCard(tokens)
        .accessibilityElement(children: .combine)
    }
}

private struct BadgeGrid: View {
    let badges: [GamificationBadge]
    let tokens: ColorTokens

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 12)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(badges) { badge in
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(badge.isEarned
                                  ? Color(hexToken: tokens.accent).opacity(0.18)
                                  : Color(hexToken: tokens.primary).opacity(0.06))
                        Image(systemName: badge.isEarned ? "rosette" : "lock.fill")
                            .font(.title2)
                            .foregroundStyle(badge.isEarned
                                             ? Color(hexToken: tokens.accent)
                                             : Color(hexToken: tokens.onSurfaceSecondary))
                    }
                    .frame(width: 56, height: 56)
                    Text(badge.name)
                        .font(.caption.weight(.medium))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .foregroundStyle(badge.isEarned
                                         ? Color(hexToken: tokens.onSurface)
                                         : Color(hexToken: tokens.onSurfaceSecondary))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .padding(.horizontal, 8)
                .background(Color(hexToken: tokens.surfaceElevated), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(badge.isEarned ? Color(hexToken: tokens.accent).opacity(0.4) : Color(hexToken: tokens.outline).opacity(0.5), lineWidth: 1)
                )
                .opacity(badge.isEarned ? 1 : 0.7)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(badge.name))
                .accessibilityValue(Text(badge.isEarned ? "gamification.badge_earned" : "gamification.badge_locked"))
            }
        }
    }
}
