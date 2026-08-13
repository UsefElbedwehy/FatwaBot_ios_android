import CoreKit
import Foundation

/// A single scheduled azkar/hadith reminder the platform layer will register.
/// Mirror of Android `PlannedContentReminder`.
public struct PlannedContentReminder: Equatable, Sendable, Identifiable {
    public enum Kind: String, Sendable, CaseIterable {
        case azkar
        case hadith

        /// Where a tap lands. Reuses the canonical route table rather than a
        /// hand-rolled URL string, so a renamed host can't silently break taps.
        public var deepLink: DeepLink {
            switch self {
            case .azkar: return .azkar
            case .hadith: return .hadith
            }
        }
    }

    public let id: String
    public let kind: Kind
    /// The azkar/hadith item this reminder is showing, so the app can attribute it.
    public let contentID: String
    /// The collection (hadith) or category (azkar) `contentID` belongs to.
    /// Carried through so a notification tap can select the right chip before
    /// scrolling to the item, without having to load the whole corpus just to
    /// find which collection an id lives in.
    public let categorySlug: String?
    public let fireDate: Date
    /// Notification-template key resolved to localized text at registration time.
    public let titleKey: String
    /// Already-truncated scripture text — content, not a template key.
    public let body: String

    public var deepLink: DeepLink { kind.deepLink }

    public init(
        id: String, kind: Kind, contentID: String, categorySlug: String? = nil,
        fireDate: Date, titleKey: String, body: String
    ) {
        self.id = id
        self.kind = kind
        self.contentID = contentID
        self.categorySlug = categorySlug
        self.fireDate = fireDate
        self.titleKey = titleKey
        self.body = body
    }
}

/// One candidate line of content, stripped down to what a notification needs.
/// The planner takes these rather than `AzkarItem`/`HadithEntry` so it stays a
/// pure function over plain data — the app layer decides which field (Arabic
/// text vs. translation) to feed in for the current locale.
public struct ContentSnippet: Equatable, Sendable {
    public let id: String
    /// Which collection (hadith) or category (azkar) owns this item — see
    /// `PlannedContentReminder.categorySlug` for why this travels along.
    public let categorySlug: String?
    public let text: String

    public init(id: String, categorySlug: String? = nil, text: String) {
        self.id = id
        self.categorySlug = categorySlug
        self.text = text
    }
}

/// User-facing preferences for the daily azkar/hadith reminders.
/// Mirror of Android `ContentReminderPreferences`.
public struct ContentReminderPreferences: Equatable, Sendable, Codable {
    public var enabled: Bool
    /// How many reminders to spread across the day. Owner decision: default 2
    /// (one azkar, one hadith), user-adjustable 0–5, where 0 means off.
    public var perDay: Int

    public static let countRange = 0...5
    public static let defaultPerDay = 2

    public init(enabled: Bool = true, perDay: Int = defaultPerDay) {
        self.enabled = enabled
        self.perDay = Self.clamp(perDay)
    }

    /// The count the planner actually uses. The toggle and a count of 0 are two
    /// routes to the same "off", and both have to be honoured — otherwise a user
    /// who dragged the stepper to 0 keeps getting notifications.
    public var effectiveCount: Int { enabled ? Self.clamp(perDay) : 0 }

    private static func clamp(_ n: Int) -> Int {
        max(countRange.lowerBound, min(countRange.upperBound, n))
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        perDay = Self.clamp(try c.decodeIfPresent(Int.self, forKey: .perDay) ?? Self.defaultPerDay)
    }
}

/// Pure builder for the rolling azkar/hadith reminder schedule. No platform
/// APIs and no clock reads — the caller supplies `now`, the calendar and the
/// content pool — so this is fully unit-testable and identical in intent to the
/// Android port, exactly like `PrayerKit.NotificationPlanner`.
///
/// ## Why the "randomness" is seeded
/// Re-planning happens on every app launch and every settings change. A real
/// RNG would hand out different times each pass, so the app would cancel the
/// pending notification and re-register it somewhere else — the user would see
/// duplicates, or silently lose the day's reminder when the new time landed in
/// the past. Every time and every pick is therefore derived from
/// `(calendar day, slot index)` through `splitmix64`: same day, same schedule,
/// no matter how many times the planner runs.
public enum ContentReminderPlanner {
    /// iOS refuses to hold more than 64 pending local notifications.
    public static let iosPendingLimit = 64

    /// What the prayer schedule already reserves — the value of
    /// `PrayerKit.NotificationPlanner.iosBudget`. It is restated here (rather
    /// than imported) only because ContentKit must not depend on PrayerKit;
    /// the app layer passes the real constant into `remainingBudget(prayerReserve:)`
    /// so there is a single source of truth at runtime.
    public static let assumedPrayerReserve = 48

    /// The 16 slots left over once prayer notifications have taken theirs.
    /// Overshooting this is not a soft failure: iOS drops the *oldest* pending
    /// requests, which would quietly delete prayer notifications.
    public static let defaultBudget = iosPendingLimit - assumedPrayerReserve

    /// Waking hours only — owner decision: nobody gets woken at 03:00.
    public static let windowStartHour = 9
    public static let windowEndHour = 21

    /// Notification bodies get elided by the OS well before this; a long hadith
    /// is truncated at a word boundary rather than shown as a wall of text.
    public static let bodyCharacterLimit = 120

    /// How far ahead to lay out reminders. The budget usually bites first (16
    /// slots is a bit over three days at 5/day); planning a week means a user
    /// who doesn't open the app still gets reminders until the budget runs out.
    public static let defaultHorizonDays = 7

    /// Slots left for content once the prayer schedule has taken its reservation.
    public static func remainingBudget(prayerReserve: Int) -> Int {
        max(0, iosPendingLimit - prayerReserve)
    }

    public static func plan(
        azkar: [ContentSnippet],
        hadith: [ContentSnippet],
        preferences: ContentReminderPreferences,
        now: Date,
        calendar: Calendar,
        horizonDays: Int = defaultHorizonDays,
        budget: Int = defaultBudget
    ) -> [PlannedContentReminder] {
        let count = preferences.effectiveCount
        // An empty pool yields an empty plan rather than a crash: on a fresh
        // install the seed content may not have been read off disk yet.
        guard count > 0, budget > 0, horizonDays > 0, !(azkar.isEmpty && hadith.isEmpty) else { return [] }

        let windowMinutes = (windowEndHour - windowStartHour) * 60
        // One reminder per equal sub-window, so two reminders can never collide
        // and can never bunch up at the same end of the day.
        let slotMinutes = windowMinutes / count
        guard slotMinutes > 0 else { return [] }

        var planned: [PlannedContentReminder] = []
        let today = calendar.startOfDay(for: now)

        for dayOffset in 0..<horizonDays {
            guard let dayStart = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }
            let parts = calendar.dateComponents([.year, .month, .day], from: dayStart)
            let dayKey = UInt64((parts.year ?? 0) * 10_000 + (parts.month ?? 0) * 100 + (parts.day ?? 0))

            for slot in 0..<count {
                // The seed is the whole determinism story: day + slot in, a fixed
                // time and a fixed pick out.
                let seed = splitmix64(dayKey &* 64 &+ UInt64(slot))

                let minuteInSlot = Int(seed % UInt64(slotMinutes))
                let minuteOfDay = windowStartHour * 60 + slot * slotMinutes + minuteInSlot
                // Added as calendar minutes so a DST jump shifts the reminder with
                // the wall clock instead of landing an hour outside the window.
                guard let fire = calendar.date(byAdding: .minute, value: minuteOfDay, to: dayStart) else { continue }
                guard fire > now else { continue }

                // Alternate azkar/hadith so the default of 2 is one of each, and
                // fall back to the other pool when one of them is empty.
                var kind: PlannedContentReminder.Kind = slot.isMultiple(of: 2) ? .azkar : .hadith
                if pool(for: kind, azkar: azkar, hadith: hadith).isEmpty {
                    kind = kind == .azkar ? .hadith : .azkar
                }
                let candidates = pool(for: kind, azkar: azkar, hadith: hadith)
                guard !candidates.isEmpty else { continue }

                // Re-hashed so the item choice doesn't correlate with the minute.
                let pickSeed = splitmix64(seed ^ 0xA076_1D64_78BD_642F)
                let item = candidates[Int(pickSeed % UInt64(candidates.count))]

                planned.append(PlannedContentReminder(
                    id: "content-\(kind.rawValue)-\(dayKey)-\(slot)",
                    kind: kind,
                    contentID: item.id,
                    categorySlug: item.categorySlug,
                    fireDate: fire,
                    titleKey: "notif.content.\(kind.rawValue).title",
                    body: truncate(item.text)
                ))
            }
        }

        return Array(planned.sorted { $0.fireDate < $1.fireDate }.prefix(budget))
    }

    /// Shortens to `limit` characters on a word boundary, so a hadith never gets
    /// cut mid-word. Whitespace is collapsed first — the seed JSON carries
    /// newlines that would otherwise eat most of the visible line.
    public static func truncate(_ text: String, limit: Int = bodyCharacterLimit) -> String {
        let words = text.split(whereSeparator: \.isWhitespace).map(String.init)
        let collapsed = words.joined(separator: " ")
        guard collapsed.count > limit else { return collapsed }

        // Leave room for the ellipsis so the result still fits inside `limit`.
        var kept = ""
        for word in words {
            let candidate = kept.isEmpty ? word : kept + " " + word
            if candidate.count > limit - 1 { break }
            kept = candidate
        }
        // A single word longer than the whole limit has no boundary to cut on.
        if kept.isEmpty { kept = String(collapsed.prefix(limit - 1)) }
        return kept + "…"
    }

    private static func pool(
        for kind: PlannedContentReminder.Kind,
        azkar: [ContentSnippet],
        hadith: [ContentSnippet]
    ) -> [ContentSnippet] {
        kind == .azkar ? azkar : hadith
    }

    /// splitmix64 — a small, fast, well-mixed integer hash. Written out rather
    /// than using `Hasher` because Swift's is seeded per process: the same day
    /// would hash differently after a relaunch, which is precisely the bug this
    /// whole design exists to avoid. The Android port uses the identical
    /// constants, so both platforms derive the same schedule.
    static func splitmix64(_ value: UInt64) -> UInt64 {
        var z = value &+ 0x9E37_79B9_7F4A_7C15
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
