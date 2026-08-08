import AppIntents
import CoreKit
import SwiftUI
import WidgetKit

private let appGroup = "group.com.fatwabot.app"

private func counterStore() -> TasbihWidgetCounterStore? {
    FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: appGroup)
        .map { TasbihWidgetCounterStore(appGroupContainer: $0) }
}

/// Adds one to the tally. Kept separate from the reset intent rather than
/// parameterised, because the two carry very different weight: increment is the
/// whole point of the widget and reset destroys a count someone has been
/// accumulating. Distinct intents make the destructive one impossible to invoke
/// by passing the wrong value.
struct IncrementTasbihIntent: AppIntent {
    static var title: LocalizedStringResource = "Count"
    static var openAppWhenRun: Bool = false

    init() {}

    func perform() async throws -> some IntentResult {
        if let store = counterStore() {
            store.write(store.read().incremented())
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "TasbihWidget")
        return .result()
    }
}

struct ResetTasbihIntent: AppIntent {
    static var title: LocalizedStringResource = "Reset count"
    static var openAppWhenRun: Bool = false

    init() {}

    func perform() async throws -> some IntentResult {
        if let store = counterStore() {
            store.write(store.read().reset())
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "TasbihWidget")
        return .result()
    }
}

// MARK: - Provider

struct TasbihEntry: TimelineEntry {
    let date: Date
    let count: Int
}

struct TasbihProvider: TimelineProvider {
    func placeholder(in context: Context) -> TasbihEntry {
        TasbihEntry(date: Date(), count: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (TasbihEntry) -> Void) {
        let now = Date()
        completion(TasbihEntry(date: now, count: counterStore()?.read().current(on: now) ?? 0))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TasbihEntry>) -> Void) {
        let now = Date()
        let entry = TasbihEntry(date: now, count: counterStore()?.read().current(on: now) ?? 0)
        // Refresh at the start of tomorrow so the tally visibly rolls over
        // rather than waiting for the next tap to reveal it had reset.
        let tomorrow = Calendar.current.nextDate(
            after: now, matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime
        ) ?? now.addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(tomorrow)))
    }
}

// MARK: - Widget

struct TasbihWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TasbihWidget", provider: TasbihProvider()) { entry in
            TasbihWidgetView(entry: entry)
                .brandWidgetContainer()
        }
        .configurationDisplayName(Text("widget.tasbih.name"))
        .description(Text("widget.tasbih.desc"))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct TasbihWidgetView: View {
    let entry: TasbihEntry

    var body: some View {
        ZStack(alignment: .topLeading) {
            // The whole tile counts. A small centre button would be the obvious
            // layout and the wrong one — dhikr is repeated without looking, so
            // the target should be everything the thumb can land on.
            Button(intent: IncrementTasbihIntent()) {
                VStack(spacing: 2) {
                    Text("\(entry.count)")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(brandPrimary)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text("widget.tasbih.hint")
                        .font(.caption2)
                        .foregroundStyle(brandMuted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("widget.tasbih.name"))
            .accessibilityValue(Text("\(entry.count)"))

            // Reset sits in a corner, deliberately small: it must be reachable
            // without being in the path of a thumb tapping the same tile a
            // hundred times.
            Button(intent: ResetTasbihIntent()) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.caption2)
                    .foregroundStyle(brandMuted)
                    .padding(6)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("widget.tasbih.reset"))
        }
    }
}
