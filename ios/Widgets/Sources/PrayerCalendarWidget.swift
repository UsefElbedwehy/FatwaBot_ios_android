import CoreKit
import PrayerKit
import SwiftUI
import WidgetKit

/// الصلاة والتقويم — the next prayer beside a Hijri week strip.
///
/// Small is the countdown alone; medium adds the calendar. The two halves come
/// from different sources on purpose: the countdown needs the app-written prayer
/// snapshot, while the calendar is pure Hijri arithmetic. So on a device that
/// has never had a location the calendar half still renders — a widget that
/// blanks entirely because one of its two panels lacks data is worse than one
/// that shows the half it can.
struct PrayerCalendarWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PrayerCalendarWidget", provider: PrayerTimelineProvider()) { entry in
            PrayerCalendarView(entry: entry)
                .brandWidgetContainer()
                .widgetURL(DeepLink.prayer.url)
        }
        .configurationDisplayName(Text("widget.prayer_calendar.name"))
        .description(Text("widget.prayer_calendar.desc"))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct PrayerCalendarView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PrayerEntry

    private var week: HijriWeek { HijriWeek.containing(entry.date) }

    var body: some View {
        if family == .systemSmall {
            countdown
        } else {
            HStack(spacing: 10) {
                countdown.frame(maxWidth: .infinity)
                Divider().overlay(brandMuted.opacity(0.25))
                calendar.frame(maxWidth: .infinity)
            }
        }
    }

    private var countdown: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let next = entry.snapshot?.nextEntry(after: entry.date) {
                Text(PrayerWidgetSnapshot.title(for: next.prayer))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(brandPrimary)
                Text(next.time, style: .timer)
                    .font(.title3.monospacedDigit().weight(.semibold))
                    .foregroundStyle(brandPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(next.time, style: .time)
                    .font(.caption)
                    .foregroundStyle(brandMuted)
                if let location = entry.snapshot?.locationName, !location.isEmpty {
                    Text(location)
                        .font(.caption2)
                        .foregroundStyle(brandMuted)
                        .lineLimit(1)
                }
            } else {
                // No snapshot yet. The Hijri date still works, so say something
                // true rather than showing an empty panel.
                Text("\(week.days.first(where: \.isToday)?.number ?? 0) \(week.monthName)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(brandPrimary)
                Text("widget.open_app")
                    .font(.caption2)
                    .foregroundStyle(brandMuted)
            }
            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }

    private var calendar: some View {
        VStack(spacing: 4) {
            Text("\(week.monthName) \(String(week.year))")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(brandPrimary)
                .lineLimit(1)
            HStack(spacing: 2) {
                ForEach(Array(week.days.enumerated()), id: \.offset) { _, day in
                    VStack(spacing: 1) {
                        Text(day.weekdayLabel)
                            .font(.system(size: 8))
                            .foregroundStyle(brandMuted)
                        Text("\(day.number)")
                            .font(.system(size: 11, weight: day.isToday ? .bold : .regular))
                            .monospacedDigit()
                            .foregroundStyle(day.isToday ? brandSurface : brandInk)
                            .frame(width: 16, height: 16)
                            .background(
                                Circle().fill(day.isToday ? brandPrimary : .clear)
                            )
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}
