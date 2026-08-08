import CoreKit
import PrayerKit
import SwiftUI
import WidgetKit

/// The whole prayer day on one tile: every time including الشروق, the night
/// markers, the date in both calendars, and the countdown to what is next.
///
/// ## Why a separate widget rather than a bigger timeline widget
/// `PrayerTimelineWidget` answers "what is coming"; it lists upcoming prayers
/// across the day boundary and deliberately omits sunrise. This answers "what is
/// today" — a fixed six-row sheet that does not reorder as the day progresses,
/// which is what makes it scannable. Same data, genuinely different question;
/// merging them would compromise both.
///
/// ## Why it needs no network and no app launch
/// Everything comes from the app-group snapshot, which now carries full day
/// sheets (`PrayerWidgetSnapshot.DaySheet`). A device that has opened the app
/// once renders this correctly for 48 hours with the app never running again.
struct PrayerDaySheetWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PrayerDaySheetWidget", provider: PrayerTimelineProvider()) { entry in
            PrayerDaySheetView(entry: entry)
                .brandWidgetContainer()
                .widgetURL(DeepLink.prayer.url)
        }
        .configurationDisplayName(Text("widget.day_sheet.name"))
        .description(Text("widget.day_sheet.desc"))
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct PrayerDaySheetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PrayerEntry

    private var sheet: PrayerWidgetSnapshot.DaySheet? {
        entry.snapshot?.sheet(for: entry.date)
    }

    var body: some View {
        // A snapshot written by an older app build has no day sheets. Falling
        // back to the next-prayer view keeps the tile useful instead of showing
        // a placeholder until the user happens to open the app.
        if let snapshot = entry.snapshot, let sheet {
            VStack(alignment: .leading, spacing: family == .systemLarge ? 8 : 5) {
                header(snapshot)
                if family == .systemLarge { countdown(snapshot) }
                Divider().overlay(brandMuted.opacity(0.3))
                times(sheet)
                if family == .systemLarge, sheet.midnight != nil {
                    Divider().overlay(brandMuted.opacity(0.3))
                    nightRow(sheet)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } else {
            NextPrayerView(entry: entry)
        }
    }

    // MARK: - Pieces

    private func header(_ snapshot: PrayerWidgetSnapshot) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(snapshot.locationName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(brandPrimary)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text("\(snapshot.hijriDay) \(snapshot.hijriMonthName) \(String(snapshot.hijriYear))")
                .font(.caption2)
                .foregroundStyle(brandMuted)
                .lineLimit(1)
        }
    }

    private func countdown(_ snapshot: PrayerWidgetSnapshot) -> some View {
        Group {
            if let next = snapshot.nextEntry(after: entry.date) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(PrayerWidgetSnapshot.title(for: next.prayer))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(brandPrimary)
                    Text(next.time, style: .timer)
                        .font(.title3.monospacedDigit().weight(.semibold))
                        .foregroundStyle(brandPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text(next.time, style: .time)
                        .font(.caption)
                        .foregroundStyle(brandMuted)
                }
            }
        }
    }

    /// The six times as a fixed grid.
    ///
    /// `nextEntry` is what decides the highlight, not "the first time still in
    /// the future" — those differ at sunrise, and computing it locally here is
    /// how the sheet would end up highlighting الشروق as the next prayer while
    /// the countdown above it correctly said الظهر.
    private func times(_ sheet: PrayerWidgetSnapshot.DaySheet) -> some View {
        let nextPrayer = entry.snapshot?.nextEntry(after: entry.date)?.prayer
        let columns = Array(
            repeating: GridItem(.flexible(), spacing: 4), count: family == .systemLarge ? 3 : 6
        )
        return LazyVGrid(columns: columns, spacing: family == .systemLarge ? 8 : 2) {
            ForEach(sheet.times, id: \.prayer) { item in
                cell(
                    title: PrayerWidgetSnapshot.title(for: item.prayer),
                    time: item.time,
                    isNext: item.prayer == nextPrayer,
                    // Sunrise is not a prayer and must not read as one, at any
                    // size. Tinting it is the cheapest honest signal.
                    isMuted: item.prayer == "sunrise"
                )
            }
        }
    }

    private func nightRow(_ sheet: PrayerWidgetSnapshot.DaySheet) -> some View {
        HStack {
            if let midnight = sheet.midnight {
                cell(title: NSLocalizedString("prayer.midnight", comment: ""),
                     time: midnight, isNext: false, isMuted: true)
            }
            if let lastThird = sheet.lastThird {
                cell(title: NSLocalizedString("prayer.last_third", comment: ""),
                     time: lastThird, isNext: false, isMuted: true)
            }
        }
    }

    private func cell(title: String, time: Date, isNext: Bool, isMuted: Bool) -> some View {
        VStack(spacing: 1) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(isNext ? brandPrimary : brandMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(time, style: .time)
                .font(.caption.weight(isNext ? .bold : .regular))
                .monospacedDigit()
                .foregroundStyle(isNext ? brandPrimary : (isMuted ? brandMuted : brandInk))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }
}
