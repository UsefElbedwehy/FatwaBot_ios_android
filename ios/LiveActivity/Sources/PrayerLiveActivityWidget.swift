import ActivityKit
import CoreKit
import PrayerKit
import SwiftUI
import WidgetKit

// Brand colors (Live Activities can't fetch the server theme; mirrors the
// same bundled values used by FatwaBotWidgets/DesignSystemKit.bundledDefault).
private let brandPrimary = Color(red: 0x7A / 255, green: 0x2A / 255, blue: 0x2A / 255)
private let brandSurface = Color(red: 0xFA / 255, green: 0xF3 / 255, blue: 0xEC / 255)

private func title(for rawPrayer: String) -> String {
    NSLocalizedString("prayer.\(rawPrayer)", comment: "")
}

/// `Text(timerInterval:countsDown:)` needs a live, non-inverted range — but
/// the activity can still be on screen for up to 30 min after `prayerTime`
/// passes (the ADR-0016 stale grace window) if the app hasn't ticked over to
/// the next prayer yet. Fall back to a static "now" label rather than handing
/// SwiftUI an inverted range or a misleading count-up.
private struct CountdownText: View {
    let prayerTime: Date

    var body: some View {
        if Date() <= prayerTime {
            Text(timerInterval: Date()...prayerTime, countsDown: true)
        } else {
            Text("live_activity.now")
        }
    }
}

struct PrayerLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PrayerActivityAttributes.self) { context in
            LockScreenView(attributes: context.attributes, state: context.state)
                .widgetURL(DeepLink.prayer.url)
                .activityBackgroundTint(brandSurface)
                .activitySystemActionForegroundColor(brandPrimary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "moon.stars.fill")
                        .foregroundStyle(brandPrimary)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    CountdownText(prayerTime: context.state.prayerTime)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(brandPrimary)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(title(for: context.state.prayerName))
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.attributes.locationName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "moon.stars.fill")
                    .foregroundStyle(brandPrimary)
            } compactTrailing: {
                CountdownText(prayerTime: context.state.prayerTime)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(brandPrimary)
                    .frame(width: 44)
            } minimal: {
                Image(systemName: "moon.stars.fill")
                    .foregroundStyle(brandPrimary)
            }
        }
    }
}

private struct LockScreenView: View {
    let attributes: PrayerActivityAttributes
    let state: PrayerActivityAttributes.ContentState

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title(for: state.prayerName))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(brandPrimary)
                Text(attributes.locationName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            CountdownText(prayerTime: state.prayerTime)
                .font(.title2.monospacedDigit())
                .foregroundStyle(brandPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding()
    }
}

@main
struct FatwaBotLiveActivity: WidgetBundle {
    var body: some Widget {
        PrayerLiveActivityWidget()
    }
}
