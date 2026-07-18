#if canImport(ActivityKit) && os(iOS)
import ActivityKit
import Foundation

/// Live Activity contract (ADR-0016) — shared by the app (starts/updates/ends
/// the activity) and the FatwaBotLiveActivity widget extension (renders it).
/// Static attributes carry only identifying data; the mutable ContentState is
/// exactly the countdown target, rendered client-side via `Text(timerInterval:)`
/// with zero app wake-ups between updates.
public struct PrayerActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        public let prayerName: String // PrayerName.rawValue
        public let prayerTime: Date

        public init(prayerName: String, prayerTime: Date) {
            self.prayerName = prayerName
            self.prayerTime = prayerTime
        }
    }

    public let locationName: String

    public init(locationName: String) {
        self.locationName = locationName
    }
}
#endif
