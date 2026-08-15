import CoreKit
import PrayerKit
import SwiftUI
import WidgetKit

// Brand colors (widgets can't fetch the server theme; use bundled brand values
// matching DesignSystemKit.DesignTokens.bundledDefault). Shared across every
// widget in this extension (see GamificationWidgets.swift).
let brandPrimary = Color(red: 0x7A / 255, green: 0x2A / 255, blue: 0x2A / 255)
let brandSurface = Color(red: 0xFA / 255, green: 0xF3 / 255, blue: 0xEC / 255)
/// Text colours to go with `brandSurface`.
///
/// These have to exist, and have to be applied explicitly, because
/// `brandSurface` is a *fixed* cream literal — it does not darken in dark mode.
/// SwiftUI's `.primary` / `.secondary` do adapt, so in dark mode they resolve to
/// near-white and the text vanishes against the cream card. Mirrors the same
/// guard on Android (`WidgetTheme.kt`).
let brandInk = Color(red: 0x2A / 255, green: 0x21 / 255, blue: 0x18 / 255)
let brandMuted = Color(red: 0x6B / 255, green: 0x5E / 255, blue: 0x52 / 255)

extension Text {
    /// A prayer time at a specific timezone. `Text(_:style:.time)` always
    /// renders in the device's timezone with no way to override it — wrong
    /// here, since a prayer time is local to the resolved location, not to
    /// whatever timezone the device viewing the widget happens to be set to.
    init(prayerTime date: Date, timeZone: TimeZone) {
        self.init(date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, timeZone: timeZone)))
    }
}

extension View {
    /// The cream card every home-screen widget sits on, plus the ink default
    /// that must travel with it.
    ///
    /// Applying the foreground style here rather than per-`Text` means a new
    /// label added later inherits a readable colour by default instead of
    /// silently reintroducing the white-on-cream bug.
    ///
    /// Deliberately NOT used by the `.accessory*` families: those render on the
    /// Lock Screen with a clear background and are tinted by the system, so
    /// forcing ink there would make them invisible instead.
    func brandWidgetContainer() -> some View {
        foregroundStyle(brandInk)
            .containerBackground(brandSurface, for: .widget)
    }
}

// MARK: - Next Prayer

struct NextPrayerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NextPrayerWidget", provider: PrayerTimelineProvider()) { entry in
            NextPrayerView(entry: entry)
                .brandWidgetContainer()
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
        if let snapshot = entry.snapshot, let next = snapshot.nextEntry(after: entry.date) {
            VStack(alignment: .leading, spacing: 4) {
                Text("home.next_prayer")
                    .font(.caption2)
                    .foregroundStyle(brandMuted)
                Text(PrayerWidgetSnapshot.title(for: next.prayer))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(brandPrimary)
                Text(next.time, style: .timer)
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(brandPrimary)
                Spacer()
                Text(prayerTime: next.time, timeZone: snapshot.timeZone)
                    .font(.caption)
                    .foregroundStyle(brandMuted)
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
                .brandWidgetContainer()
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
        // The location's civil day in an explicitly Gregorian calendar — not
        // the device's, whose *identifier* isn't guaranteed Gregorian (e.g.
        // `ar_SA` defaults to Islamic Umm al-Qura), and not its timezone
        // either, both of which can silently drop or duplicate rows.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = snapshot.timeZone
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
                        .font(.caption).foregroundStyle(brandMuted)
                }
                if family == .systemLarge {
                    // Full-day vertical list, the coming prayer highlighted.
                    VStack(spacing: 0) {
                        ForEach(Array(todaysEntries.prefix(6)), id: \.time) { item in
                            let isNext = item.prayer == next?.prayer
                            HStack {
                                Image(systemName: isNext ? "chevron.right.circle.fill" : "circle")
                                    .font(.caption2)
                                    .foregroundStyle(isNext ? brandPrimary : brandMuted.opacity(0.5))
                                Text(PrayerWidgetSnapshot.title(for: item.prayer))
                                    .font(.body)
                                    .fontWeight(isNext ? .bold : .regular)
                                    .foregroundStyle(isNext ? brandPrimary : brandInk)
                                Spacer()
                                Text(prayerTime: item.time, timeZone: snapshot.timeZone)
                                    .font(.body.monospacedDigit())
                                    .fontWeight(isNext ? .bold : .regular)
                                    .foregroundStyle(isNext ? brandPrimary : brandMuted)
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
                                    .foregroundStyle(isNext ? brandPrimary : brandMuted)
                                Text(prayerTime: item.time, timeZone: snapshot.timeZone)
                                    .font(.caption2.monospacedDigit())
                                    .fontWeight(isNext ? .bold : .regular)
                                    .foregroundStyle(isNext ? brandPrimary : brandMuted)
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
        let timeZone = entry.snapshot?.timeZone ?? .current
        switch family {
        case .accessoryInline:
            if let next {
                Text("\(PrayerWidgetSnapshot.title(for: next.prayer)) • ") + Text(prayerTime: next.time, timeZone: timeZone)
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
                        Text(prayerTime: next.time, timeZone: timeZone)
                            .font(.system(size: 11).monospacedDigit())
                    }
                }
                .progressViewStyle(.circular)
            } else {
                VStack(spacing: 1) {
                    Image(systemName: "moon.stars.fill").font(.caption2)
                    if let next {
                        Text(prayerTime: next.time, timeZone: timeZone).font(.caption2.monospacedDigit())
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
                        Text(prayerTime: next.time, timeZone: timeZone)
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

// MARK: - Home Screen small "all prayers" widget

struct AllPrayersSmallWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AllPrayersSmallWidget", provider: PrayerTimelineProvider()) { entry in
            AllPrayersSmallView(entry: entry)
                .brandWidgetContainer()
                .widgetURL(DeepLink.prayer.url)
        }
        .configurationDisplayName(Text("widget.all_prayers.name"))
        .description(Text("widget.all_prayers.desc"))
        .supportedFamilies([.systemSmall])
    }
}

struct AllPrayersSmallView: View {
    let entry: PrayerEntry

    private var todaySheet: PrayerWidgetSnapshot.DaySheet? {
        entry.snapshot?.sheet(for: entry.date)
    }

    /// The most recently passed time — Fajr..Isha and sunrise alike — so the
    /// dot marks where the day actually is, not just the next prayer.
    private var currentPrayer: String? {
        todaySheet?.times.last { $0.time <= entry.date }?.prayer
    }

    /// Two columns of three read top-to-bottom, left then right — the same
    /// split as the (now-retired) Lock Screen six-up layout, just with more
    /// room to breathe at Home Screen small size.
    private var columns: ([PrayerWidgetSnapshot.Entry], [PrayerWidgetSnapshot.Entry]) {
        guard let times = todaySheet?.times else { return ([], []) }
        let mid = (times.count + 1) / 2
        return (Array(times.prefix(mid)), Array(times.dropFirst(mid)))
    }

    var body: some View {
        if let sheet = todaySheet, !sheet.times.isEmpty {
            let timeZone = entry.snapshot?.timeZone ?? .current
            HStack(alignment: .top, spacing: 10) {
                column(columns.0, timeZone: timeZone)
                column(columns.1, timeZone: timeZone)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            WidgetPlaceholder()
        }
    }

    private func column(_ items: [PrayerWidgetSnapshot.Entry], timeZone: TimeZone) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(items, id: \.time) { item in
                let isCurrent = item.prayer == currentPrayer
                VStack(alignment: .leading, spacing: 0) {
                    Text(PrayerWidgetSnapshot.title(for: item.prayer))
                        .font(.system(size: 10, weight: isCurrent ? .bold : .regular))
                        .foregroundStyle(isCurrent ? brandPrimary : brandMuted)
                        .lineLimit(1)
                    Text(prayerTime: item.time, timeZone: timeZone)
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(isCurrent ? brandPrimary : brandInk)
                }
            }
        }
    }
}

// MARK: - Lock Screen previous/next/after-next prayer window (accessory family)

struct AllPrayersAccessoryWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AllPrayersAccessoryWidget", provider: PrayerTimelineProvider()) { entry in
            AllPrayersAccessoryView(entry: entry)
                .containerBackground(.clear, for: .widget)
                .widgetURL(DeepLink.prayer.url)
        }
        .configurationDisplayName(Text("widget.prayer_window.name"))
        .description(Text("widget.prayer_window.desc"))
        .supportedFamilies([.accessoryRectangular])
    }
}

struct AllPrayersAccessoryView: View {
    let entry: PrayerEntry

    /// Previous / next / the one after next — three real prayers (client
    /// direction: sunrise doesn't count), spanning the day boundary via
    /// `upcoming` rather than a single day's sheet, same source as
    /// `NextPrayerAccessoryView.previousTime`.
    private var window: (previous: PrayerWidgetSnapshot.Entry?, next: PrayerWidgetSnapshot.Entry?, afterNext: PrayerWidgetSnapshot.Entry?) {
        guard let upcoming = entry.snapshot?.upcoming else { return (nil, nil, nil) }
        let previous = upcoming.last { $0.time <= entry.date }
        let future = upcoming.filter { $0.time > entry.date }
        return (previous, future.first, future.dropFirst().first)
    }

    var body: some View {
        let items = [window.previous, window.next, window.afterNext].compactMap { $0 }
        let timeZone = entry.snapshot?.timeZone ?? .current
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 3) {
                ForEach(items, id: \.time) { item in
                    let isNext = item.time == window.next?.time
                    HStack(spacing: 4) {
                        Image(systemName: isNext ? "circle.fill" : "circle")
                            .font(.system(size: 6))
                        Text(PrayerWidgetSnapshot.title(for: item.prayer))
                            .font(.system(size: 11))
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(prayerTime: item.time, timeZone: timeZone)
                            .font(.system(size: 11).monospacedDigit())
                    }
                    .widgetAccentable(isNext)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            Text("widget.open_app").font(.caption2)
        }
    }
}

// MARK: - Hijri Date

struct HijriDateWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "HijriDateWidget", provider: PrayerTimelineProvider()) { entry in
            HijriDateView(entry: entry)
                .brandWidgetContainer()
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
                Text(verbatim: "\(snapshot.hijriYear) هـ").font(.caption).foregroundStyle(brandMuted)
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
            Text("widget.open_app").font(.caption2).foregroundStyle(brandMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

@main
struct FatwaBotWidgets: WidgetBundle {
    var body: some Widget {
        NextPrayerWidget()
        PrayerTimelineWidget()
        PrayerDaySheetWidget()
        RandomDuaWidget()
        HijriDateWidget()
        StreakWidget()
        DailyChallengeWidget()
        WorshipTrackerWidget()
        TasbihWidget()
        OccasionWidget()
        PrayerCalendarWidget()
        HadithWidget()
        NextPrayerAccessoryWidget()
        DuaAccessoryWidget()
        AllPrayersAccessoryWidget()
        AllPrayersSmallWidget()
    }
}
