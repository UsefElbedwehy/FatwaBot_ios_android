import CoreKit
import PrayerKit
import SwiftUI
import WidgetKit

/// رمضان والعيد — days remaining to Ramadan and the two Eids.
///
/// Zero network and zero snapshot dependency: this is arithmetic over the
/// Umm al-Qura calendar, so it renders correctly on a device that has never
/// opened the app and never had a location.
struct OccasionEntry: TimelineEntry {
    let date: Date
    let countdowns: [IslamicOccasionCountdown]
}

struct OccasionProvider: TimelineProvider {
    /// Mirrors the Hijri adjustment the user set for the rest of the app, so the
    /// countdown cannot disagree with the Hijri date shown beside it.
    private var offsetDays: Int {
        UserDefaults(suiteName: "group.com.fatwabot.app")?
            .integer(forKey: "hijriOffsetDays") ?? 0
    }

    private func entry(at date: Date) -> OccasionEntry {
        OccasionEntry(
            date: date,
            countdowns: IslamicOccasionCalculator.all(from: date, offsetDays: offsetDays)
        )
    }

    func placeholder(in context: Context) -> OccasionEntry { entry(at: Date()) }

    func getSnapshot(in context: Context, completion: @escaping (OccasionEntry) -> Void) {
        completion(entry(at: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<OccasionEntry>) -> Void) {
        let now = Date()
        // One entry per day for a week, so the number ticks down without the
        // system needing to wake the extension daily.
        let entries = (0..<7).compactMap { offset -> OccasionEntry? in
            Calendar.current.date(byAdding: .day, value: offset, to: now).map { entry(at: $0) }
        }
        let reload = Calendar.current.date(byAdding: .day, value: 6, to: now) ?? now
        completion(Timeline(entries: entries, policy: .after(reload)))
    }
}

struct OccasionWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "OccasionWidget", provider: OccasionProvider()) { entry in
            OccasionWidgetView(entry: entry)
                .brandWidgetContainer()
        }
        .configurationDisplayName(Text("widget.occasion.name"))
        .description(Text("widget.occasion.desc"))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct OccasionWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: OccasionEntry

    var body: some View {
        // Small shows only the nearest occasion — three rows at that size is
        // three unreadable rows, and the nearest one is the one being waited for.
        let shown = family == .systemSmall
            ? Array(entry.countdowns.prefix(1))
            : entry.countdowns

        VStack(alignment: .leading, spacing: family == .systemSmall ? 2 : 6) {
            ForEach(shown, id: \.occasion.rawValue) { item in
                if family == .systemSmall {
                    Spacer(minLength: 0)
                    Text(LocalizedStringKey(item.occasion.titleKey))
                        .font(.headline)
                        .foregroundStyle(brandPrimary)
                    Text("\(item.daysRemaining)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(brandPrimary)
                        .minimumScaleFactor(0.5)
                    Text("occasion.days")
                        .font(.caption2)
                        .foregroundStyle(brandMuted)
                    Spacer(minLength: 0)
                } else {
                    HStack {
                        Text(LocalizedStringKey(item.occasion.titleKey))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(brandInk)
                        Spacer()
                        Text("\(item.daysRemaining)")
                            .font(.title3.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(brandPrimary)
                        Text("occasion.days")
                            .font(.caption2)
                            .foregroundStyle(brandMuted)
                    }
                    if item.occasion.rawValue != shown.last?.occasion.rawValue {
                        Divider().overlay(brandMuted.opacity(0.25))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: family == .systemSmall ? .center : .top)
    }
}
