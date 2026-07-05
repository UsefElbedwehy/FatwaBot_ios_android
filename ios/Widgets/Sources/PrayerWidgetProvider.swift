import PrayerKit
import SwiftUI
import WidgetKit

/// Shared timeline entry for all prayer widgets. Reads the app-written snapshot
/// from the app group; widget processes never touch the network (ADR-0003).
struct PrayerEntry: TimelineEntry {
    let date: Date
    let snapshot: PrayerWidgetSnapshot?
}

struct PrayerTimelineProvider: TimelineProvider {
    static let appGroup = "group.com.fatwabot.app"

    private func store() -> WidgetSnapshotStore? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: Self.appGroup)
            .map { WidgetSnapshotStore(appGroupContainer: $0) }
    }

    func placeholder(in context: Context) -> PrayerEntry {
        PrayerEntry(date: Date(), snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (PrayerEntry) -> Void) {
        completion(PrayerEntry(date: Date(), snapshot: store()?.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerEntry>) -> Void) {
        let snapshot = store()?.read()
        let now = Date()
        // One refresh point per upcoming prayer so the "next prayer" advances
        // without waking the app; reload after the last known entry.
        var entries: [PrayerEntry] = [PrayerEntry(date: now, snapshot: snapshot)]
        if let upcoming = snapshot?.upcoming {
            for entry in upcoming where entry.time > now {
                entries.append(PrayerEntry(date: entry.time, snapshot: snapshot))
            }
        }
        let reload = snapshot?.upcoming.last?.time ?? now.addingTimeInterval(3600)
        completion(Timeline(entries: entries, policy: .after(reload)))
    }
}

extension PrayerWidgetSnapshot {
    /// Localized prayer display name for the widget (bundle strings).
    static func title(for rawPrayer: String) -> String {
        NSLocalizedString("prayer.\(rawPrayer)", comment: "")
    }
}
