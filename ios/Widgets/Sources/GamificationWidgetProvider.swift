import CoreKit
import SwiftUI
import WidgetKit

/// Shared timeline entry for the Streak/Daily-Challenge widgets. Reads the
/// app-written snapshot from the app group; widget processes never touch the
/// network (same discipline as PrayerTimelineProvider).
struct GamificationEntry: TimelineEntry {
    let date: Date
    let snapshot: GamificationWidgetSnapshot?
}

struct GamificationTimelineProvider: TimelineProvider {
    static let appGroup = "group.com.fatwabot.app"

    private func store() -> GamificationWidgetSnapshotStore? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: Self.appGroup)
            .map { GamificationWidgetSnapshotStore(appGroupContainer: $0) }
    }

    func placeholder(in context: Context) -> GamificationEntry {
        GamificationEntry(date: Date(), snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (GamificationEntry) -> Void) {
        completion(GamificationEntry(date: Date(), snapshot: store()?.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GamificationEntry>) -> Void) {
        let snapshot = store()?.read()
        let entry = GamificationEntry(date: Date(), snapshot: snapshot)
        // No further app-side edges to schedule around (unlike prayer times);
        // reload once daily so a stale snapshot doesn't linger indefinitely
        // even if the app hasn't been opened.
        let reload = Date().addingTimeInterval(24 * 3600)
        completion(Timeline(entries: [entry], policy: .after(reload)))
    }
}
