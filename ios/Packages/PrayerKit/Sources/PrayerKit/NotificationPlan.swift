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
    ///
    /// The gap is **per prayer**, because mosques don't use one figure: Fajr
    /// typically waits longer than the rest. Keyed by `PrayerName.rawValue` so
    /// the persisted JSON is a readable `{"fajr": 20}` rather than the array of
    /// alternating keys/values Swift emits for an enum-keyed dictionary.
    public var iqamaEnabled: Bool
    public var iqamaOffsetsByPrayer: [String: Int]
    /// A single reminder at the start of the last third of the night.
    public var lastThirdEnabled: Bool

    public static let offsetRange = 1...60

    /// Mosque convention: a longer gap before Fajr's congregation, shorter for
    /// the rest. Sunrise is not a prayer and never gets an iqama.
    public static let defaultIqamaOffsets: [String: Int] = [
        PrayerName.fajr.rawValue: 20,
        PrayerName.dhuhr.rawValue: 10,
        PrayerName.asr.rawValue: 10,
        PrayerName.maghrib.rawValue: 10,
        PrayerName.isha.rawValue: 10,
    ]

    public init(
        adhanEnabled: Bool = true,
        preAdhanEnabled: Bool = true,
        preAdhanOffsetMinutes: Int = 10,
        iqamaEnabled: Bool = false,
        iqamaOffsetsByPrayer: [String: Int] = defaultIqamaOffsets,
        lastThirdEnabled: Bool = false
    ) {
        self.adhanEnabled = adhanEnabled
        self.preAdhanEnabled = preAdhanEnabled
        self.preAdhanOffsetMinutes = Self.clamp(preAdhanOffsetMinutes)
        self.iqamaEnabled = iqamaEnabled
        self.iqamaOffsetsByPrayer = iqamaOffsetsByPrayer.mapValues(Self.clamp)
        self.lastThirdEnabled = lastThirdEnabled
    }

    /// Gap for one prayer, falling back to the mosque default so a partially
    /// populated dictionary can never silently drop a prayer's reminder.
    public func iqamaOffset(for prayer: PrayerName) -> Int {
        iqamaOffsetsByPrayer[prayer.rawValue]
            ?? Self.defaultIqamaOffsets[prayer.rawValue]
            ?? 10
    }

    private static func clamp(_ m: Int) -> Int { max(offsetRange.lowerBound, min(offsetRange.upperBound, m)) }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case adhanEnabled, preAdhanEnabled, preAdhanOffsetMinutes
        case iqamaEnabled, iqamaOffsetsByPrayer, lastThirdEnabled
        /// Pre-2026-07 shape: one gap shared by every prayer.
        case iqamaOffsetMinutes
    }

    /// Hand-written so an upgrade doesn't wipe existing settings. The stored JSON
    /// on an installed device still has the old scalar `iqamaOffsetMinutes`;
    /// synthesized decoding would throw on the missing new key and the caller
    /// would fall back to defaults, silently resetting whatever the user chose.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        adhanEnabled = try c.decodeIfPresent(Bool.self, forKey: .adhanEnabled) ?? true
        preAdhanEnabled = try c.decodeIfPresent(Bool.self, forKey: .preAdhanEnabled) ?? true
        preAdhanOffsetMinutes = Self.clamp(try c.decodeIfPresent(Int.self, forKey: .preAdhanOffsetMinutes) ?? 10)
        iqamaEnabled = try c.decodeIfPresent(Bool.self, forKey: .iqamaEnabled) ?? false
        lastThirdEnabled = try c.decodeIfPresent(Bool.self, forKey: .lastThirdEnabled) ?? false

        if let perPrayer = try c.decodeIfPresent([String: Int].self, forKey: .iqamaOffsetsByPrayer) {
            iqamaOffsetsByPrayer = perPrayer.mapValues(Self.clamp)
        } else if let legacy = try c.decodeIfPresent(Int.self, forKey: .iqamaOffsetMinutes) {
            // Carry the single old value onto every prayer, so a user who set 15
            // keeps 15 everywhere instead of being reset to the 20/10 defaults.
            let clamped = Self.clamp(legacy)
            iqamaOffsetsByPrayer = Self.defaultIqamaOffsets.mapValues { _ in clamped }
        } else {
            iqamaOffsetsByPrayer = Self.defaultIqamaOffsets
        }
    }

    /// Explicit because `CodingKeys` carries a legacy-only case, which blocks the
    /// synthesized encoder. Deliberately writes ONLY the current shape — the old
    /// scalar is read for migration and then never written again.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(adhanEnabled, forKey: .adhanEnabled)
        try c.encode(preAdhanEnabled, forKey: .preAdhanEnabled)
        try c.encode(preAdhanOffsetMinutes, forKey: .preAdhanOffsetMinutes)
        try c.encode(iqamaEnabled, forKey: .iqamaEnabled)
        try c.encode(iqamaOffsetsByPrayer, forKey: .iqamaOffsetsByPrayer)
        try c.encode(lastThirdEnabled, forKey: .lastThirdEnabled)
    }
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
                    let fire = prayerTime.addingTimeInterval(
                        TimeInterval(preferences.iqamaOffset(for: prayer) * 60)
                    )
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
