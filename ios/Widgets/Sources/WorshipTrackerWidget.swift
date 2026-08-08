import AppIntents
import CoreKit
import SwiftUI
import WidgetKit

/// Marks one deed done from the home screen.
///
/// Deliberately does no network. The widget process writes to `WorshipInbox`
/// and the app uploads on next foreground — the same offline-first discipline
/// every other widget follows (ADR-0003), and the reason a tap works on the
/// underground with no spinner and no failure state.
struct LogWorshipIntent: AppIntent {
    static var title: LocalizedStringResource = "Log worship"
    /// The app must not come forward. The entire value of the tile is logging
    /// Fajr without leaving the home screen.
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Deed")
    var deedRawValue: String

    init() {}

    init(deed: WorshipDeed) {
        self.deedRawValue = deed.rawValue
    }

    func perform() async throws -> some IntentResult {
        guard let deed = WorshipDeed(rawValue: deedRawValue) else { return .result() }
        if let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: WorshipTrackerProvider.appGroup
        ) {
            WorshipInbox(appGroupContainer: container).deposit(
                WorshipInboxEntry(eventType: deed.eventType, metadata: deed.metadata)
            )
        }
        // Re-render so the tile fills in immediately. Without this the tap
        // registers but nothing visibly happens until the next timeline refresh,
        // which reads as a broken button.
        WidgetCenter.shared.reloadTimelines(ofKind: "WorshipTrackerWidget")
        return .result()
    }
}

// MARK: - Provider

struct WorshipTrackerEntry: TimelineEntry {
    let date: Date
    /// Deeds to show as done — the app's record for today unioned with taps not
    /// yet drained.
    let completed: Set<String>
}

struct WorshipTrackerProvider: TimelineProvider {
    static let appGroup = "group.com.fatwabot.app"

    private var container: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroup)
    }

    /// The union is the whole trick. The snapshot alone lags behind taps until
    /// the app next runs; the inbox alone empties the moment it drains. Either
    /// on its own makes tiles flicker back to undone at exactly the wrong time.
    private func completed(at date: Date) -> Set<String> {
        guard let container else { return [] }
        let recorded = GamificationWidgetSnapshotStore(appGroupContainer: container)
            .read()?.completedToday ?? []
        let pending = WorshipInbox(appGroupContainer: container).peek()
            .filter { Calendar.current.isDate($0.occurredAt, inSameDayAs: date) }
            .compactMap { entry -> String? in
                entry.metadata["prayer"]
                    ?? entry.metadata["category"].map { "azkar_\($0)" }
            }
        return Set(recorded).union(pending)
    }

    func placeholder(in context: Context) -> WorshipTrackerEntry {
        WorshipTrackerEntry(date: Date(), completed: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (WorshipTrackerEntry) -> Void) {
        completion(WorshipTrackerEntry(date: Date(), completed: completed(at: Date())))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WorshipTrackerEntry>) -> Void) {
        let now = Date()
        let entry = WorshipTrackerEntry(date: now, completed: completed(at: now))
        // Refresh at the start of tomorrow so the tiles clear for the new day
        // without waiting for the app to run.
        let tomorrow = Calendar.current.nextDate(
            after: now, matching: DateComponents(hour: 0, minute: 0),
            matchingPolicy: .nextTime
        ) ?? now.addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(tomorrow)))
    }
}

// MARK: - Widget

struct WorshipTrackerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WorshipTrackerWidget", provider: WorshipTrackerProvider()) { entry in
            WorshipTrackerView(entry: entry)
                .brandWidgetContainer()
        }
        .configurationDisplayName(Text("widget.worship_tracker.name"))
        .description(Text("widget.worship_tracker.desc"))
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct WorshipTrackerView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WorshipTrackerEntry

    /// Medium shows the five prayers; large adds the two adhkar.
    private var deeds: [WorshipDeed] {
        family == .systemLarge ? WorshipDeed.allCases : WorshipDeed.prayers
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("widget.worship_tracker.name")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(brandPrimary)
                Spacer()
                Text("\(entry.completed.intersection(Set(deeds.map(\.rawValue))).count)/\(deeds.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(brandMuted)
            }
            // Rows of three that each claim an equal share of the height, rather
            // than a LazyVGrid pinned to the top by a trailing Spacer. On
            // `systemLarge` that layout left the bottom 60% of the tile empty
            // cream, which reads as broken rather than spacious — the tiles are
            // the content, so they should fill the space they are given.
            //
            // The last row is padded with invisible slots so three tiles and two
            // tiles are the same width; without it the final row stretches its
            // tiles to double width and the grid stops looking like a grid.
            let rows = deeds.chunked(into: 3)
            VStack(spacing: 6) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 6) {
                        ForEach(row, id: \.rawValue) { deed in
                            DeedTile(deed: deed, isDone: entry.completed.contains(deed.rawValue))
                        }
                        ForEach(0..<(3 - row.count), id: \.self) { _ in
                            Color.clear.frame(maxWidth: .infinity)
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct DeedTile: View {
    let deed: WorshipDeed
    let isDone: Bool

    var body: some View {
        Button(intent: LogWorshipIntent(deed: deed)) {
            VStack(spacing: 2) {
                Image(systemName: isDone ? "checkmark.circle.fill" : deed.symbolName)
                    .font(.caption)
                    .foregroundStyle(isDone ? brandPrimary : brandMuted)
                Text(LocalizedStringKey(deed.titleKey))
                    .font(.caption2)
                    .foregroundStyle(isDone ? brandPrimary : brandInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(brandPrimary.opacity(isDone ? 0.16 : 0.06))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(LocalizedStringKey(deed.titleKey)))
        .accessibilityValue(Text(isDone ? "deed.done" : "deed.not_done"))
    }
}

private extension Array {
    /// Fixed-size chunks, last one short. Not in the standard library.
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
    }
}
