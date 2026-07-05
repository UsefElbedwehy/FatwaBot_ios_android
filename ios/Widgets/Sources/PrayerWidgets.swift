import PrayerKit
import SwiftUI
import WidgetKit

// Brand colors (widgets can't fetch the server theme; use bundled brand values
// matching DesignSystemKit.DesignTokens.bundledDefault).
private let brandPrimary = Color(red: 0x7A / 255, green: 0x2A / 255, blue: 0x2A / 255)
private let brandSurface = Color(red: 0xFA / 255, green: 0xF3 / 255, blue: 0xEC / 255)

// MARK: - Next Prayer

struct NextPrayerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NextPrayerWidget", provider: PrayerTimelineProvider()) { entry in
            NextPrayerView(entry: entry)
                .containerBackground(brandSurface, for: .widget)
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
        }
        .configurationDisplayName(Text("widget.timeline.name"))
        .description(Text("widget.timeline.desc"))
        .supportedFamilies([.systemMedium])
    }
}

struct PrayerTimelineView: View {
    let entry: PrayerEntry

    private var todaysEntries: [PrayerWidgetSnapshot.Entry] {
        guard let snapshot = entry.snapshot else { return [] }
        let calendar = Calendar.current
        return snapshot.upcoming.filter { calendar.isDate($0.time, inSameDayAs: entry.date) }
    }

    var body: some View {
        if let snapshot = entry.snapshot {
            let next = snapshot.nextEntry(after: entry.date)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(snapshot.locationName).font(.caption.weight(.medium))
                    Spacer()
                    Text("\(snapshot.hijriMonthName) \(snapshot.hijriDay)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                HStack(spacing: 10) {
                    ForEach(Array(todaysEntries.prefix(6)), id: \.time) { item in
                        VStack(spacing: 3) {
                            Text(PrayerWidgetSnapshot.title(for: item.prayer))
                                .font(.caption2)
                                .foregroundStyle(item.prayer == next?.prayer ? brandPrimary : .secondary)
                            Text(item.time, style: .time)
                                .font(.caption2.monospacedDigit())
                                .fontWeight(item.prayer == next?.prayer ? .bold : .regular)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } else {
            WidgetPlaceholder()
        }
    }
}

// MARK: - Hijri Date

struct HijriDateWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "HijriDateWidget", provider: PrayerTimelineProvider()) { entry in
            HijriDateView(entry: entry)
                .containerBackground(brandSurface, for: .widget)
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
                Text(snapshot.hijriMonthName).font(.headline)
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
        HijriDateWidget()
    }
}
