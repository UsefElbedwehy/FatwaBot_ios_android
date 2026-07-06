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

    public var body: some View {
        List {
            if let error = viewModel.error {
                Section {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                }
            }
            if !viewModel.profile.streaks.isEmpty {
                Section("gamification.streaks_section") {
                    ForEach(viewModel.profile.streaks) { streak in
                        StreakRow(streak: streak, tokens: tokens)
                    }
                }
            }
            if !viewModel.profile.missions.isEmpty {
                Section("gamification.missions_section") {
                    ForEach(viewModel.profile.missions) { mission in
                        MissionRow(mission: mission, tokens: tokens)
                    }
                }
            }
            if !viewModel.profile.badges.isEmpty {
                Section("gamification.badges_section") {
                    ForEach(viewModel.profile.badges) { badge in
                        BadgeRow(badge: badge, tokens: tokens)
                    }
                }
            }
            if !viewModel.isLoading && viewModel.profile == .empty && viewModel.error == nil {
                Section {
                    Text("gamification.empty_state")
                        .font(.subheadline)
                        .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                }
            }
        }
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

private struct StreakRow: View {
    let streak: GamificationStreak
    let tokens: ColorTokens

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(streak.name).font(.body.weight(.medium))
                if streak.graceRemaining > 0 {
                    Text("gamification.grace_remaining \(streak.graceRemaining)")
                        .font(.caption)
                        .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(streak.currentLength)")
                    .font(.title2.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Color(hexToken: tokens.primary))
                Text("gamification.longest \(streak.longestLength)")
                    .font(.caption2)
                    .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
            }
        }
    }
}

private struct MissionRow: View {
    let mission: GamificationMission
    let tokens: ColorTokens

    private var progressFraction: Double {
        mission.target > 0 ? Double(mission.progress) / Double(mission.target) : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(mission.name).font(.body.weight(.medium))
                Spacer()
                Text("\(mission.progress)/\(mission.target)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
            }
            ProgressView(value: min(progressFraction, 1))
                .tint(Color(hexToken: tokens.primary))
        }
        .padding(.vertical, 4)
    }
}

private struct BadgeRow: View {
    let badge: GamificationBadge
    let tokens: ColorTokens

    var body: some View {
        HStack {
            Image(systemName: badge.isEarned ? "rosette" : "circle.dashed")
                .foregroundStyle(badge.isEarned ? Color(hexToken: tokens.accent) : Color(hexToken: tokens.onSurfaceSecondary))
            Text(badge.name)
                .foregroundStyle(badge.isEarned ? Color(hexToken: tokens.onSurface) : Color(hexToken: tokens.onSurfaceSecondary))
            Spacer()
            if badge.isEarned {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color(hexToken: tokens.primary))
            }
        }
    }
}
