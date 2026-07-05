import Foundation

/// A single scheduled local notification the platform layer will register.
public struct PlannedNotification: Equatable, Sendable, Identifiable {
    public enum Kind: String, Sendable {
        case adhan       // at prayer time
        case preAdhan    // offset minutes before prayer time
    }

    public let id: String
    public let prayer: PrayerName
    public let kind: Kind
    public let fireDate: Date
    /// Notification-template key resolved to localized text at registration time.
    public let titleKey: String
    public let bodyKey: String

    public init(id: String, prayer: PrayerName, kind: Kind, fireDate: Date, titleKey: String, bodyKey: String) {
        self.id = id
        self.prayer = prayer
        self.kind = kind
        self.fireDate = fireDate
        self.titleKey = titleKey
        self.bodyKey = bodyKey
    }
}

/// Per-prayer notification preferences (backend catalog-driven; ADR-0013).
public struct PrayerNotificationPreferences: Equatable, Sendable {
    /// Which prayers fire an adhan notification.
    public var adhanEnabled: Set<PrayerName>
    /// Pre-adhan reminder offset in minutes (0 = disabled), per prayer.
    public var preAdhanOffsetMinutes: [PrayerName: Int]

    public init(
        adhanEnabled: Set<PrayerName> = Set(PrayerName.allCases.filter(\.isPrayer)),
        preAdhanOffsetMinutes: [PrayerName: Int] = [:]
    ) {
        self.adhanEnabled = adhanEnabled
        self.preAdhanOffsetMinutes = preAdhanOffsetMinutes
    }
}

/// Pure builder for the rolling local-notification schedule (docs/features/prayer.md).
/// No platform APIs, no clock reads — the caller supplies `now` and the timeline,
/// so this is fully unit-testable and identical in intent to the Android port.
public enum NotificationPlanner {
    /// iOS allows 64 pending notifications; reserve headroom for other categories
    /// (azkar in M2, campaigns). Prayer schedule is capped here.
    public static let iosBudget = 48

    /// Builds the ordered, future-only, budget-capped plan from a precomputed timeline.
    /// - Parameters:
    ///   - timeline: consecutive `PrayerDay`s starting at or before `now`.
    ///   - preferences: per-prayer adhan/pre-adhan settings.
    ///   - now: current instant; past fire dates are dropped.
    ///   - budget: max notifications to schedule.
    public static func plan(
        timeline: [PrayerDay],
        preferences: PrayerNotificationPreferences,
        now: Date,
        budget: Int = iosBudget
    ) -> [PlannedNotification] {
        var planned: [PlannedNotification] = []

        for day in timeline {
            let key = dayKey(day.date)
            for prayer in PrayerName.allCases where prayer.isPrayer {
                let prayerTime = day.time(prayer)

                if preferences.adhanEnabled.contains(prayer), prayerTime > now {
                    planned.append(PlannedNotification(
                        id: "adhan-\(key)-\(prayer.rawValue)",
                        prayer: prayer,
                        kind: .adhan,
                        fireDate: prayerTime,
                        titleKey: "notif.adhan.title.\(prayer.rawValue)",
                        bodyKey: "notif.adhan.body"
                    ))
                }

                if let offset = preferences.preAdhanOffsetMinutes[prayer], offset > 0 {
                    let fire = prayerTime.addingTimeInterval(TimeInterval(-offset * 60))
                    if fire > now {
                        planned.append(PlannedNotification(
                            id: "pre-\(key)-\(prayer.rawValue)",
                            prayer: prayer,
                            kind: .preAdhan,
                            fireDate: fire,
                            titleKey: "notif.pre_adhan.title.\(prayer.rawValue)",
                            bodyKey: "notif.pre_adhan.body"
                        ))
                    }
                }
            }
        }

        return Array(planned.sorted { $0.fireDate < $1.fireDate }.prefix(budget))
    }

    private static func dayKey(_ components: DateComponents) -> String {
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d%02d%02d", year, month, day)
    }
}
