import AwradFeature
import Foundation
import PrayerFeature

/// Prayer times for the anchored wird reminders, resolved eagerly.
///
/// ## Why this exists at all
/// The planner takes a `@Sendable` lookup closure and calls it from an async
/// context. The first version reached back into `PrayerViewModel` through
/// `MainActor.assumeIsolated`, which traps when the caller is not actually on
/// the main actor — and it was not. Tapping "Follow Fajr time" terminated the
/// app immediately. A UI test caught it; no unit test could have, because the
/// planner's own tests inject a plain closure.
///
/// So the times are resolved **up front on the main actor** and the closure the
/// planner receives only reads a dictionary. It captures no actor-isolated
/// state, which makes the `@Sendable` requirement honest rather than asserted.
enum WirdAnchorTimes {
    /// Prayers a wird can be anchored to. Resolving only these keeps the
    /// precompute to a handful of engine calls.
    private static var anchorPrayers: [String] {
        Array(Set(FixedWirdSlot.allCases.compactMap(\.anchorPrayer)))
    }

    @MainActor
    static func lookup(from viewModel: PrayerViewModel) -> WirdReminderPlanner.PrayerTimeLookup {
        var resolved: [String: Date] = [:]
        for offset in 0..<WirdReminderPlanner.prayerAnchorHorizonDays {
            for prayer in anchorPrayers {
                if let time = viewModel.prayerTime(dayOffset: offset, prayer: prayer) {
                    resolved["\(offset)|\(prayer)"] = time
                }
            }
        }
        // Value-captured, so the returned closure touches nothing isolated.
        return { offset, prayer in resolved["\(offset)|\(prayer)"] }
    }
}
