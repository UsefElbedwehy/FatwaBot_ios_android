import DesignSystemKit
import PrayerKit
import SwiftUI

struct AmbientHeaderView: View {
    let hijri: HijriDate?
    let locationName: String?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greetingKey)
                .font(.title2.weight(.bold))
            HStack(spacing: 8) {
                if let hijri {
                    Text("\(hijri.monthName) \(hijri.day)، \(String(hijri.year)) هـ")
                }
                Text(Date().formatted(.dateTime.weekday(.wide).day().month(.wide)))
                if let locationName, !locationName.isEmpty {
                    Label(locationName, systemImage: "location.fill")
                }
            }
            .font(.caption)
            .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var greetingKey: LocalizedStringKey {
        Calendar.current.component(.hour, from: Date()) < 15 ? "home.greeting.morning" : "home.greeting.evening"
    }

    private var tokens: ColorTokens {
        colorScheme == .dark ? DesignTokens.bundledDefault.dark : DesignTokens.bundledDefault.light
    }
}

struct PrayerHeroCard: View {
    let content: HomeHeroContent
    @Environment(\.colorScheme) private var colorScheme

    private var tokens: ColorTokens {
        colorScheme == .dark ? DesignTokens.bundledDefault.dark : DesignTokens.bundledDefault.light
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("home.next_prayer")
                        .font(.caption)
                        .foregroundStyle(Color(hexToken: tokens.onPrimary).opacity(0.75))
                    Text(content.nextPrayer.heroTitle)
                        .font(.largeTitle.weight(.bold))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    // Live countdown without a timer: system-updating text.
                    Text(content.nextTime, style: .relative)
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                    Text(content.nextTime.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(Color(hexToken: tokens.onPrimary).opacity(0.75))
                }
            }
            timeline
        }
        .foregroundStyle(Color(hexToken: tokens.onPrimary))
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color(hexToken: tokens.primary), Color(hexToken: tokens.primary).opacity(0.85)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 20)
        )
        .accessibilityElement(children: .combine)
    }

    /// Thin five-prayer strip: passed prayers dimmed, next highlighted.
    private var timeline: some View {
        HStack(spacing: 6) {
            ForEach(content.today.ordered.filter { $0.name.isPrayer }, id: \.name) { entry in
                let state = entryState(entry.name)
                VStack(spacing: 4) {
                    Circle()
                        .fill(Color(hexToken: tokens.onPrimary).opacity(state == .past ? 0.35 : 1))
                        .frame(width: state == .next ? 8 : 5, height: state == .next ? 8 : 5)
                    Text(entry.name.heroTitle)
                        .font(.caption2)
                        .opacity(state == .past ? 0.5 : 1)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private enum EntryState { case past, next, upcoming }

    private func entryState(_ name: PrayerName) -> EntryState {
        if name == content.nextPrayer { return .next }
        let order = PrayerName.allCases.filter(\.isPrayer)
        let nextIndex = order.firstIndex(of: content.nextPrayer) ?? 0
        let index = order.firstIndex(of: name) ?? 0
        return index < nextIndex ? .past : .upcoming
    }
}

struct AskSectionView: View {
    let enabled: Bool
    @Environment(\.colorScheme) private var colorScheme

    private var tokens: ColorTokens {
        colorScheme == .dark ? DesignTokens.bundledDefault.dark : DesignTokens.bundledDefault.light
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("home.ask.title")
                .font(.headline)
            HStack {
                Image(systemName: "magnifyingglass")
                Text("home.ask.placeholder")
                Spacer()
            }
            .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
            .padding(14)
            .background(Color(hexToken: tokens.surfaceElevated), in: RoundedRectangle(cornerRadius: 14))
            HStack(spacing: 8) {
                intentChip("home.ask.intent.fatwa", icon: "text.magnifyingglass")
                intentChip("home.ask.intent.hadith", icon: "book")
                intentChip("home.ask.intent.general", icon: "bubble.left.and.text.bubble.right")
            }
            if !enabled {
                Label { Text("home.ask.coming_soon") } icon: { Image(systemName: "sparkles") }
                    .font(.caption)
                    .foregroundStyle(Color(hexToken: tokens.accent))
            }
            Text("home.ask.trust_line")
                .font(.caption2)
                .foregroundStyle(Color(hexToken: tokens.onSurfaceSecondary))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(enabled ? 1 : 0.75)
    }

    private func intentChip(_ key: LocalizedStringKey, icon: String) -> some View {
        Label { Text(key).lineLimit(1).minimumScaleFactor(0.8) } icon: { Image(systemName: icon) }
            .font(.caption.weight(.medium))
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
            .background(Color(hexToken: tokens.primaryContainer), in: Capsule())
            .foregroundStyle(Color(hexToken: tokens.primary))
    }
}

struct QuickActionsGrid: View {
    let onTap: (QuickAction) -> Void
    @Environment(\.colorScheme) private var colorScheme

    private var tokens: ColorTokens {
        colorScheme == .dark ? DesignTokens.bundledDefault.dark : DesignTokens.bundledDefault.light
    }

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
            ForEach(QuickAction.allCases) { action in
                Button {
                    onTap(action)
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: action.icon)
                            .font(.title3)
                        Text(action.titleKey)
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(hexToken: tokens.surfaceElevated), in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(Color(hexToken: tokens.primary))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

extension PrayerName {
    var heroTitle: LocalizedStringKey {
        switch self {
        case .fajr: "prayer.fajr"
        case .sunrise: "prayer.sunrise"
        case .dhuhr: "prayer.dhuhr"
        case .asr: "prayer.asr"
        case .maghrib: "prayer.maghrib"
        case .isha: "prayer.isha"
        }
    }
}
