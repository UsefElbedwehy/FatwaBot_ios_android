import CoreKit
import PrayerKit
import SwiftUI
import WidgetKit

// Brand colors (widgets can't fetch the server theme; use bundled brand values
// matching DesignSystemKit.DesignTokens.bundledDefault). Shared across every
// widget in this extension (see GamificationWidgets.swift).
let brandPrimary = Color(red: 0x7A / 255, green: 0x2A / 255, blue: 0x2A / 255)
let brandSurface = Color(red: 0xFA / 255, green: 0xF3 / 255, blue: 0xEC / 255)

// MARK: - Next Prayer

struct NextPrayerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NextPrayerWidget", provider: PrayerTimelineProvider()) { entry in
            NextPrayerView(entry: entry)
                .containerBackground(brandSurface, for: .widget)
                .widgetURL(DeepLink.prayer.url)
        }
        .configurationDisplayName(Text("widget.next_prayer.name"))
        .description(Text("widget.next_prayer.desc"))
        .supportedFamilies([.systemSmall])
    }
}

struct NextPrayerView: View {
    let entry: PrayerEntry

    var body: some View {
        if let next = entry.snapshot?.nextEntry(after: entry.date) {
            VStack(alignment: .leading, spacing: 4) {
                Text("home.next_prayer")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(PrayerWidgetSnapshot.title(for: next.prayer))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(brandPrimary)
                Text(next.time, style: .timer)
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(brandPrimary)
                Spacer()
                Text(next.time, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            WidgetPlaceholder()
        }
    }
}

// MARK: - Prayer Timeline

struct PrayerTimelineWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PrayerTimelineWidget", provider: PrayerTimelineProvider()) { entry in
            PrayerTimelineView(entry: entry)
                .containerBackground(brandSurface, for: .widget)
                .widgetURL(DeepLink.prayer.url)
        }
        .configurationDisplayName(Text("widget.timeline.name"))
        .description(Text("widget.timeline.desc"))
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct PrayerTimelineView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PrayerEntry

    private var todaysEntries: [PrayerWidgetSnapshot.Entry] {
        guard let snapshot = entry.snapshot else { return [] }
        let calendar = Calendar.current
        return snapshot.upcoming.filter { calendar.isDate($0.time, inSameDayAs: entry.date) }
    }

    var body: some View {
        if let snapshot = entry.snapshot {
            let next = snapshot.nextEntry(after: entry.date)
            VStack(alignment: .leading, spacing: family == .systemLarge ? 10 : 8) {
                HStack {
                    Text(snapshot.locationName)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(brandPrimary)
                    Spacer()
                    Text("\(snapshot.hijriMonthName) \(snapshot.hijriDay)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if family == .systemLarge {
                    // Full-day vertical list, the coming prayer highlighted.
                    VStack(spacing: 0) {
                        ForEach(Array(todaysEntries.prefix(6)), id: \.time) { item in
                            let isNext = item.prayer == next?.prayer
                            HStack {
                                Image(systemName: isNext ? "chevron.right.circle.fill" : "circle")
                                    .font(.caption2)
                                    .foregroundStyle(isNext ? brandPrimary : .secondary.opacity(0.5))
                                Text(PrayerWidgetSnapshot.title(for: item.prayer))
                                    .font(.body)
                                    .fontWeight(isNext ? .bold : .regular)
                                    .foregroundStyle(isNext ? brandPrimary : .primary)
                                Spacer()
                                Text(item.time, style: .time)
                                    .font(.body.monospacedDigit())
                                    .fontWeight(isNext ? .bold : .regular)
                                    .foregroundStyle(isNext ? brandPrimary : .secondary)
                            }
                            .padding(.vertical, 7)
                            .padding(.horizontal, 10)
                            .background(
                                isNext ? brandPrimary.opacity(0.10) : .clear,
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                            )
                            if item.time != todaysEntries.prefix(6).last?.time {
                                Divider().opacity(0.4)
                            }
                        }
                    }
                } else {
                    // Medium: compact row.
                    HStack(spacing: 10) {
                        ForEach(Array(todaysEntries.prefix(6)), id: \.time) { item in
                            let isNext = item.prayer == next?.prayer
                            VStack(spacing: 3) {
                                Text(PrayerWidgetSnapshot.title(for: item.prayer))
                                    .font(.caption2)
                                    .foregroundStyle(isNext ? brandPrimary : .secondary)
                                Text(item.time, style: .time)
                                    .font(.caption2.monospacedDigit())
                                    .fontWeight(isNext ? .bold : .regular)
                                    .foregroundStyle(isNext ? brandPrimary : .secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } else {
            WidgetPlaceholder()
        }
    }
}

// MARK: - Lock Screen / Notification Center next-prayer (accessory families)

struct NextPrayerAccessoryWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NextPrayerAccessoryWidget", provider: PrayerTimelineProvider()) { entry in
            NextPrayerAccessoryView(entry: entry)
                .containerBackground(.clear, for: .widget)
                .widgetURL(DeepLink.prayer.url)
        }
        .configurationDisplayName(Text("widget.next_prayer.name"))
        .description(Text("widget.next_prayer.desc"))
        .supportedFamilies([.accessoryRectangular, .accessoryInline, .accessoryCircular])
    }
}

struct NextPrayerAccessoryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PrayerEntry

    /// Start of the current interval — the most recent prayer already passed —
    /// so the circular family can draw how far through the gap we are.
    private var previousTime: Date? {
        entry.snapshot?.upcoming.last { $0.time <= entry.date }?.time
    }

    var body: some View {
        let next = entry.snapshot?.nextEntry(after: entry.date)
        switch family {
        case .accessoryInline:
            if let next {
                Text("\(PrayerWidgetSnapshot.title(for: next.prayer)) • \(next.time, style: .time)")
            } else {
                Text("home.next_prayer")
            }

        case .accessoryCircular:
            // A live ring showing progress toward the next prayer, with the
            // time in the middle — the ring ticks on its own, no app wake-ups.
            if let next, let start = previousTime, start < next.time {
                ProgressView(timerInterval: start...next.time, countsDown: false) {
                    EmptyView()
                } currentValueLabel: {
                    VStack(spacing: -1) {
                        Image(systemName: "moon.stars.fill").font(.system(size: 9))
                        Text(next.time, style: .time)
                            .font(.system(size: 11).monospacedDigit())
                    }
                }
                .progressViewStyle(.circular)
            } else {
                VStack(spacing: 1) {
                    Image(systemName: "moon.stars.fill").font(.caption2)
                    if let next {
                        Text(next.time, style: .time).font(.caption2.monospacedDigit())
                    }
                }
            }

        default: // accessoryRectangular
            // Name + clock time on one row, live countdown beneath. Every line
            // earns its place: no static "next prayer" caption (the glyph says
            // it), and both "when" and "how long" are visible at a glance.
            if let next {
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Image(systemName: "moon.stars.fill").font(.caption2)
                        Text(PrayerWidgetSnapshot.title(for: next.prayer))
                            .font(.headline)
                            .lineLimit(1)
                        Spacer(minLength: 2)
                        Text(next.time, style: .time)
                            .font(.subheadline.monospacedDigit())
                    }
                    .widgetAccentable()
                    Text(next.time, style: .timer)
                        .font(.title3.monospacedDigit().weight(.medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            } else {
                Text("widget.open_app").font(.caption2)
            }
        }
    }
}

// MARK: - Hijri Date

struct HijriDateWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "HijriDateWidget", provider: PrayerTimelineProvider()) { entry in
            HijriDateView(entry: entry)
                .containerBackground(brandSurface, for: .widget)
                .widgetURL(DeepLink.prayer.url)
        }
        .configurationDisplayName(Text("widget.hijri.name"))
        .description(Text("widget.hijri.desc"))
        .supportedFamilies([.systemSmall])
    }
}

struct HijriDateView: View {
    let entry: PrayerEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            VStack(spacing: 4) {
                Text("\(snapshot.hijriDay)")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(brandPrimary)
                Text(snapshot.hijriMonthName)
                    .font(.headline)
                    .foregroundStyle(brandPrimary)
                Text(verbatim: "\(snapshot.hijriYear) هـ").font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            WidgetPlaceholder()
        }
    }
}

struct WidgetPlaceholder: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "moon.stars")
                .font(.title)
                .foregroundStyle(brandPrimary)
            Text("widget.open_app").font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

@main
struct FatwaBotWidgets: WidgetBundle {
    var body: some Widget {
        NextPrayerWidget()
        PrayerTimelineWidget()
        RandomDuaWidget()
        HijriDateWidget()
        StreakWidget()
        DailyChallengeWidget()
        NextPrayerAccessoryWidget()
        DuaAccessoryWidget()
    }
}
