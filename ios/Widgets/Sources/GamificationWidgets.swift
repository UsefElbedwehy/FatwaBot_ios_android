import CoreKit
import DesignSystemKit
import SwiftUI
import WidgetKit

// MARK: - Streak

struct StreakWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "StreakWidget", provider: GamificationTimelineProvider()) { entry in
            StreakView(entry: entry)
                .brandWidgetContainer()
                .widgetURL(DeepLink.journey.url)
        }
        .configurationDisplayName(Text("widget.streak.name"))
        .description(Text("widget.streak.desc"))
        .supportedFamilies([.systemSmall])
    }
}

struct StreakView: View {
    let entry: GamificationEntry

    var body: some View {
        if let streak = entry.snapshot?.topStreak {
            VStack(alignment: .leading, spacing: 4) {
                Text(streak.name)
                    .font(.caption2)
                    .foregroundStyle(brandMuted)
                    .lineLimit(1)
                // Same flame + mark + count the Journey tab shows, so the widget
                // and the screen it deep-links to are recognisably one thing.
                StreakBadge(
                    count: streak.currentLength,
                    size: .medium,
                    isActive: streak.currentLength > 0,
                    // Light tokens deliberately: the widget card is a fixed
                    // cream that never darkens, so dark tokens would be as
                    // unreadable here as the system colours were.
                    tokens: DesignTokens.bundledDefault.light
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
                if streak.graceRemaining > 0 {
                    Text("widget.streak.grace \(streak.graceRemaining)")
                        .font(.caption2)
                        .foregroundStyle(brandMuted)
                } else {
                    Text("widget.streak.longest \(streak.longestLength)")
                        .font(.caption2)
                        .foregroundStyle(brandMuted)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            GamificationWidgetPlaceholder()
        }
    }
}

// MARK: - Daily Challenge

struct DailyChallengeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DailyChallengeWidget", provider: GamificationTimelineProvider()) { entry in
            DailyChallengeView(entry: entry)
                .brandWidgetContainer()
                .widgetURL(DeepLink.journey.url)
        }
        .configurationDisplayName(Text("widget.daily_challenge.name"))
        .description(Text("widget.daily_challenge.desc"))
        .supportedFamilies([.systemSmall])
    }
}

struct DailyChallengeView: View {
    let entry: GamificationEntry

    private var fraction: Double {
        guard let challenge = entry.snapshot?.dailyChallenge, challenge.target > 0 else { return 0 }
        return min(Double(challenge.progress) / Double(challenge.target), 1)
    }

    var body: some View {
        if let challenge = entry.snapshot?.dailyChallenge {
            VStack(alignment: .leading, spacing: 6) {
                Text(challenge.name)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(brandPrimary)
                    .lineLimit(2)
                Spacer()
                ProgressView(value: fraction)
                    .tint(brandPrimary)
                Text("\(challenge.progress)/\(challenge.target)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(brandMuted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            GamificationWidgetPlaceholder()
        }
    }
}

struct GamificationWidgetPlaceholder: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "flame")
                .font(.title)
                .foregroundStyle(brandPrimary)
            Text("widget.open_app").font(.caption2).foregroundStyle(brandMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
