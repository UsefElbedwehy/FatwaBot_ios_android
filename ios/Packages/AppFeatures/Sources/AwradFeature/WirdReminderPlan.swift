import Foundation

/// One scheduled "did you do it today?" reminder — one per active wird.
/// Mirror of Android `PlannedWirdReminder`.
public struct PlannedWirdReminder: Equatable, Sendable, Identifiable {
    /// How the platform should fire this reminder.
    ///
    /// Two shapes because they cost different amounts. A fixed time of day is a
    /// *repeating* daily trigger — one pending slot, forever. A prayer-anchored
    /// one moves every day, so it has to be a dated one-shot per day and costs a
    /// slot per day of horizon. That difference is why the budget below counts
    /// emitted reminders rather than wirds.
    public enum Trigger: Equatable, Sendable {
        case dailyAt(hour: Int, minute: Int)
        case oneShot(Date)
    }

    public let id: String
    public let wirdId: String
    /// Interpolated into the notification title, so the user knows *which* wird
    /// they are answering for without opening the app.
    public let wirdName: String
    public let trigger: Trigger

    /// Wall-clock hour for a daily reminder. Kept for the callers and tests that
    /// predate prayer anchoring; a one-shot reports the hour it lands on.
    public var hour: Int {
        switch trigger {
        case let .dailyAt(hour, _): hour
        case let .oneShot(date): Calendar.current.component(.hour, from: date)
        }
    }

    public var minute: Int {
        switch trigger {
        case let .dailyAt(_, minute): minute
        case let .oneShot(date): Calendar.current.component(.minute, from: date)
        }
    }

    public init(id: String, wirdId: String, wirdName: String, trigger: Trigger) {
        self.id = id
        self.wirdId = wirdId
        self.wirdName = wirdName
        self.trigger = trigger
    }

    public init(id: String, wirdId: String, wirdName: String, hour: Int, minute: Int) {
        self.init(
            id: id, wirdId: wirdId, wirdName: wirdName,
            trigger: .dailyAt(hour: hour, minute: minute)
        )
    }
}

/// When a wird's reminder fires.
///
/// Client request: "اعمل خيار وقت الفجر لأذكار الصباح". A fixed clock time is a
/// poor fit for أذكار الصباح specifically — Fajr moves by over an hour across
/// the year, so 05:30 chosen in summer lands *before* Fajr in winter and the
/// reminder starts arriving at the wrong end of the window it is asking about.
public enum WirdReminderSchedule: Equatable, Sendable, Codable {
    /// Same time every day.
    case clock(hour: Int, minute: Int)
    /// Anchored to a prayer, plus an offset in minutes. Negative offsets are
    /// allowed so a wird can be asked about *before* its prayer.
    case afterPrayer(prayer: String, offsetMinutes: Int)
}

/// User-facing preferences for the daily wird reminder.
/// Mirror of Android `WirdReminderPreferences`.
/// A wall-clock time of day for one wird's reminder.
public struct WirdReminderTime: Equatable, Sendable, Codable {
    public var hour: Int
    public var minute: Int

    public init(hour: Int, minute: Int) {
        self.hour = WirdReminderPreferences.clampHour(hour)
        self.minute = WirdReminderPreferences.clampMinute(minute)
    }
}

public struct WirdReminderPreferences: Equatable, Sendable, Codable {
    public var enabled: Bool
    /// Local wall-clock hour the reminder fires at. Owner decision: 20:00 — late
    /// enough that "did you do it today?" is a fair question, early enough that
    /// the user can still act on a "no".
    public var hour: Int
    public var minute: Int

    /// Per-wird overrides, keyed by wird id.
    ///
    /// Client request: "يفضل اختيار لكل ورد وقت محدد — قيام الليل وقت، أذكار
    /// الصباح وقت". Before this there was a single time for everything the user
    /// created, and the four fixed slots used hardcoded hours nobody could
    /// change. A missing entry means "no override", so an untouched install
    /// behaves exactly as it did.
    public var timesByWird: [String: WirdReminderTime]

    /// Per-wird prayer anchoring. Present means "ignore the clock time for this
    /// wird and follow the prayer instead".
    ///
    /// Kept beside `timesByWird` rather than replacing it so a user who switches
    /// to Fajr and back gets their old clock time returned rather than reset.
    public var prayerAnchorsByWird: [String: WirdReminderSchedule]

    public static let defaultHour = 20
    public static let defaultMinute = 0

    public init(
        enabled: Bool = true,
        hour: Int = defaultHour,
        minute: Int = defaultMinute,
        timesByWird: [String: WirdReminderTime] = [:],
        prayerAnchorsByWird: [String: WirdReminderSchedule] = [:]
    ) {
        self.enabled = enabled
        self.hour = Self.clampHour(hour)
        self.minute = Self.clampMinute(minute)
        self.timesByWird = timesByWird
        self.prayerAnchorsByWird = prayerAnchorsByWird
    }

    /// The prayer this wird is anchored to, if any.
    public func prayerAnchor(forWirdId id: String) -> (prayer: String, offsetMinutes: Int)? {
        guard case let .afterPrayer(prayer, offset) = prayerAnchorsByWird[id] else { return nil }
        return (prayer, offset)
    }

    /// Copy with a wird anchored to a prayer.
    public func settingPrayerAnchor(
        prayer: String, offsetMinutes: Int, forWirdId id: String
    ) -> Self {
        var copy = self
        copy.prayerAnchorsByWird[id] = .afterPrayer(prayer: prayer, offsetMinutes: offsetMinutes)
        return copy
    }

    /// Copy with a wird's prayer anchor removed, returning it to its clock time.
    public func clearingPrayerAnchor(forWirdId id: String) -> Self {
        var copy = self
        copy.prayerAnchorsByWird[id] = nil
        return copy
    }

    /// The time a wird's reminder should fire.
    ///
    /// Resolution order, and each step exists for a reason:
    ///  1. the user's own override for this wird — an explicit choice always wins;
    ///  2. the slot's built-in hour, so أذكار الصباح is still asked about in the
    ///     morning rather than at the generic evening time;
    ///  3. the global time, which is what a user-created wird has always used.
    public func time(forWirdId id: String, slotDefaultHour: Int?) -> WirdReminderTime {
        if let override = timesByWird[id] { return override }
        if let slotDefaultHour { return WirdReminderTime(hour: slotDefaultHour, minute: 0) }
        return WirdReminderTime(hour: hour, minute: minute)
    }

    /// Copy with one wird's time set. Setting is always explicit — there is no
    /// "clear" here, because a user who opened the picker and chose a time has
    /// expressed an intent that should survive a slot-default change.
    public func settingTime(_ time: WirdReminderTime, forWirdId id: String) -> Self {
        var copy = self
        copy.timesByWird[id] = time
        return copy
    }

    public static func clampHour(_ value: Int) -> Int { max(0, min(23, value)) }
    public static func clampMinute(_ value: Int) -> Int { max(0, min(59, value)) }

    /// Decoding never throws on a bad field: a corrupt blob should cost the user
    /// their chosen time, not their reminders.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        hour = Self.clampHour(try c.decodeIfPresent(Int.self, forKey: .hour) ?? Self.defaultHour)
        minute = Self.clampMinute(try c.decodeIfPresent(Int.self, forKey: .minute) ?? Self.defaultMinute)
        // Absent on every device that has not yet set a per-wird time, which is
        // all of them at the moment this ships.
        timesByWird = (try? c.decodeIfPresent([String: WirdReminderTime].self, forKey: .timesByWird)) ?? [:]
        prayerAnchorsByWird = (try? c.decodeIfPresent(
            [String: WirdReminderSchedule].self, forKey: .prayerAnchorsByWird
        )) ?? [:]
    }
}

/// Pure builder for the daily wird reminder schedule — no platform APIs, no
/// clock reads, so it is identical in intent to the Android port and fully
/// unit-testable (same contract as `ContentReminderPlanner`).
///
/// ## Why one repeating reminder per wird rather than a rolling horizon
/// The product shape is "one notification per active wird, once a day", and the
/// text never changes (the wird's name). A single *repeating* daily trigger per
/// wird therefore costs exactly one pending slot instead of one per day, which
/// matters: iOS silently evicts the OLDEST pending requests past 64, and the
/// oldest ones are the prayer notifications.
public enum WirdReminderPlanner {
    /// Every request id starts with this, so clearing ours can't touch the
    /// prayer or content schedules.
    public static let idPrefix = "wird-reminder-"

    /// Slots carved out of the content reminders' slice of the 64-notification
    /// budget. Applied unconditionally (like the prayer reserve) so that turning
    /// wird reminders on can never push the total over the cap mid-session.
    ///
    /// Sized for the four fixed slots at their worst case, not just their count:
    /// both أذكار الصباح and أذكار المساء can be anchored to a prayer, and an
    /// anchored slot costs `prayerAnchorHorizonDays` (3) reminders, not 1 — two
    /// anchored azkar alone is 6, plus 1 each for قيام الليل and ورد القرآن at
    /// their clock time is 8. The old reserve of 5 meant anchoring *both* azkar
    /// silently dropped قيام الليل's reminder with nothing to explain why (it
    /// sorts last — see `plan` below). 10 covers that worst case with two slots
    /// left over for the user's own wirds; content reminders (`perDay` tops out
    /// at 5) still fit in what's left of the 64 either way.
    public static let notificationReserve = 10

    /// Days of dated reminders emitted for a prayer-anchored wird.
    ///
    /// Deliberately short. Each day costs a pending slot, and the app reschedules
    /// on every foreground, so a long horizon buys very little and competes with
    /// the prayer schedule for the same 64. Three days covers a weekend away
    /// from the app.
    public static let prayerAnchorHorizonDays = 3

    /// One day's prayer times, supplied by the app layer.
    ///
    /// A closure rather than a timeline type so this package keeps no dependency
    /// on PrayerKit — the planner stays pure and the app decides where the times
    /// come from.
    public typealias PrayerTimeLookup = @Sendable (_ dayOffset: Int, _ prayer: String) -> Date?

    public static func plan(
        wirds: [Wird],
        preferences: WirdReminderPreferences,
        budget: Int = notificationReserve,
        now: Date = Date(),
        prayerTime: PrayerTimeLookup? = nil
    ) -> [PlannedWirdReminder] {
        guard preferences.enabled, budget > 0 else { return [] }
        // Archived wirds are excluded here as well as in the responder: a
        // reminder for something the user retired is pure noise.
        // Creation order, with the id as a tie-breaker so the truncation the
        // budget forces is stable across runs rather than dependent on file order.
        let active = wirds.filter(\.isActive)
        let userCreated = active.filter { !$0.isFixed }.sorted {
            $0.createdAt == $1.createdAt ? $0.id < $1.id : $0.createdAt < $1.createdAt
        }
        // The four fixed slots come last in the budget queue on purpose: they are
        // on every board, so ordering them first would evict the reminders of the
        // wirds a user deliberately created. The total is still capped at
        // `budget`, exactly as before — what changed is who fills the slots.
        let fixed = active.filter(\.isFixed).sorted {
            let (left, right) = (FixedWirdSlot(wirdId: $0.id), FixedWirdSlot(wirdId: $1.id))
            return (left?.sortOrder ?? .max, $0.id) < (right?.sortOrder ?? .max, $1.id)
        }
        // The budget counts *reminders*, not wirds: a prayer-anchored wird emits
        // one per day of horizon while a clock one emits a single repeating
        // trigger, so counting wirds would silently overshoot the reserve.
        var result: [PlannedWirdReminder] = []
        for wird in userCreated + fixed {
            guard result.count < budget else { break }
            let anchor = preferences.prayerAnchor(forWirdId: wird.id)

            if let anchor, let prayerTime {
                let dated = (0..<prayerAnchorHorizonDays).compactMap { offset -> PlannedWirdReminder? in
                    guard let base = prayerTime(offset, anchor.prayer) else { return nil }
                    let fire = base.addingTimeInterval(TimeInterval(anchor.offsetMinutes * 60))
                    // Today's prayer has usually passed by the time the app is
                    // opened; scheduling it would fire immediately or be dropped.
                    guard fire > now else { return nil }
                    return PlannedWirdReminder(
                        id: "\(idPrefix)\(wird.id)-d\(offset)",
                        wirdId: wird.id,
                        wirdName: wird.name,
                        trigger: .oneShot(fire)
                    )
                }
                result.append(contentsOf: dated.prefix(budget - result.count))
                continue
            }

            // Anchored but with no prayer times available (no location yet, or a
            // caller that does not supply them): fall back to the clock time
            // rather than emitting nothing. A reminder at a slightly wrong hour
            // beats a wird that silently stops asking.
            let slotHour = wird.isFixed ? FixedWirdSlot(wirdId: wird.id)?.reminderHour : nil
            let time = preferences.time(forWirdId: wird.id, slotDefaultHour: slotHour)
            result.append(PlannedWirdReminder(
                id: idPrefix + wird.id,
                wirdId: wird.id,
                wirdName: wird.name,
                trigger: .dailyAt(hour: time.hour, minute: time.minute)
            ))
        }
        return result
    }

    /// What is left of a caller's notification budget once the wird reminders
    /// have taken their reservation. Used by the content-reminder scheduler so
    /// there is one subtraction, in one place.
    public static func budgetAfterReserve(_ budget: Int) -> Int {
        max(0, budget - notificationReserve)
    }
}
