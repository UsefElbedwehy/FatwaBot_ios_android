import Foundation

/// A single scheduled local notification the platform layer will register.
public struct PlannedNotification: Equatable, Sendable, Identifiable {
    public enum Kind: String, Sendable {
        case adhan       // at prayer time
        case preAdhan    // offset minutes before prayer time
        case iqama       // offset minutes after prayer time (congregation reminder)
        case lastThird   // start of the last third of the night (Maghrib→Fajr)
    }

    public let id: String
    public let prayer: PrayerName?   // nil for night-based notifications (last third)
    public let kind: Kind
    public let fireDate: Date
    /// Notification-template key resolved to localized text at registration time.
    public let titleKey: String
    public let bodyKey: String

    public init(id: String, prayer: PrayerName?, kind: Kind, fireDate: Date, titleKey: String, bodyKey: String) {
        self.id = id
        self.prayer = prayer
        self.kind = kind
        self.fireDate = fireDate
        self.titleKey = titleKey
        self.bodyKey = bodyKey
    }
}

/// User-facing notification preferences (docs/PRODUCT_REQUIREMENTS_2026-07.md).
/// Every notification type is individually toggleable; offsets are user-set.
public struct PrayerNotificationPreferences: Equatable, Sendable, Codable {
    /// Adhan notification at each prayer time.
    public var adhanEnabled: Bool
    /// Reminder a user-set number of minutes BEFORE the adhan.
    public var preAdhanEnabled: Bool
    public var preAdhanOffsetMinutes: Int
    /// Iqama reminder a user-set number of minutes AFTER the adhan.
    public var iqamaEnabled: Bool
    public var iqamaOffsetMinutes: Int
    /// A single reminder at the start of the last third of the night.
    public var lastThirdEnabled: Bool

    public static let offsetRange = 1...60

    public init(
        adhanEnabled: Bool = true,
        preAdhanEnabled: Bool = true,
        preAdhanOffsetMinutes: Int = 10,
        iqamaEnabled: Bool = false,
        iqamaOffsetMinutes: Int = 20,
        lastThirdEnabled: Bool = false
    ) {
        self.adhanEnabled = adhanEnabled
        self.preAdhanEnabled = preAdhanEnabled
        self.preAdhanOffsetMinutes = Self.clamp(preAdhanOffsetMinutes)
        self.iqamaEnabled = iqamaEnabled
        self.iqamaOffsetMinutes = Self.clamp(iqamaOffsetMinutes)
        self.lastThirdEnabled = lastThirdEnabled
    }

    private static func clamp(_ m: Int) -> Int { max(offsetRange.lowerBound, min(offsetRange.upperBound, m)) }
}

/// Pure builder for the rolling local-notification schedule (docs/features/prayer.md).
/// No platform APIs, no clock reads — the caller supplies `now` and the timeline,
/// so this is fully unit-testable and identical in intent to the Android port.
public enum NotificationPlanner {
    /// iOS allows 64 pending notifications; reserve headroom for other categories
    /// (azkar, campaigns). Prayer schedule is capped here.
    public static let iosBudget = 48

    public static func plan(
        timeline: [PrayerDay],
        preferences: PrayerNotificationPreferences,
        now: Date,
        budget: Int = iosBudget
    ) -> [PlannedNotification] {
        var planned: [PlannedNotification] = []

        for (index, day) in timeline.enumerated() {
            let key = dayKey(day.date)
            for prayer in PrayerName.allCases where prayer.isPrayer {
                let prayerTime = day.time(prayer)

                if preferences.adhanEnabled, prayerTime > now {
                    planned.append(PlannedNotification(
                        id: "adhan-\(key)-\(prayer.rawValue)",
                        prayer: prayer, kind: .adhan, fireDate: prayerTime,
                        titleKey: "notif.adhan.title.\(prayer.rawValue)",
                        bodyKey: "notif.adhan.body"
                    ))
                }

                if preferences.preAdhanEnabled {
                    let fire = prayerTime.addingTimeInterval(TimeInterval(-preferences.preAdhanOffsetMinutes * 60))
                    if fire > now {
                        planned.append(PlannedNotification(
                            id: "pre-\(key)-\(prayer.rawValue)",
                            prayer: prayer, kind: .preAdhan, fireDate: fire,
                            titleKey: "notif.pre_adhan.title.\(prayer.rawValue)",
                            bodyKey: "notif.pre_adhan.body"
                        ))
                    }
                }

                // Iqama reminder — a fixed number of minutes after the adhan.
                // Sunrise is excluded above (isPrayer); Fajr..Isha all get one.
                if preferences.iqamaEnabled {
                    let fire = prayerTime.addingTimeInterval(TimeInterval(preferences.iqamaOffsetMinutes * 60))
                    if fire > now {
                        planned.append(PlannedNotification(
                            id: "iqama-\(key)-\(prayer.rawValue)",
                            prayer: prayer, kind: .iqama, fireDate: fire,
                            titleKey: "notif.iqama.title.\(prayer.rawValue)",
                            bodyKey: "notif.iqama.body"
                        ))
                    }
                }
            }

            // Last third of the night: from this day's Maghrib to the next day's
            // Fajr, the final third. Needs the following day's Fajr, so only emit
            // when a next day exists in the timeline.
            if preferences.lastThirdEnabled, index + 1 < timeline.count {
                let maghrib = day.time(.maghrib)
                let fajrNext = timeline[index + 1].time(.fajr)
                if fajrNext > maghrib {
                    let nightLength = fajrNext.timeIntervalSince(maghrib)
                    let start = maghrib.addingTimeInterval(nightLength * 2.0 / 3.0)
                    if start > now {
                        planned.append(PlannedNotification(
                            id: "lastthird-\(key)",
                            prayer: nil, kind: .lastThird, fireDate: start,
                            titleKey: "notif.last_third.title",
                            bodyKey: "notif.last_third.body"
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
