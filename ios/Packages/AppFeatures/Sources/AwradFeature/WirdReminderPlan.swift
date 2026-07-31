import Foundation

/// One scheduled "did you do it today?" reminder — one per active wird.
/// Mirror of Android `PlannedWirdReminder`.
public struct PlannedWirdReminder: Equatable, Sendable, Identifiable {
    public let id: String
    public let wirdId: String
    /// Interpolated into the notification title, so the user knows *which* wird
    /// they are answering for without opening the app.
    public let wirdName: String
    public let hour: Int
    public let minute: Int

    public init(id: String, wirdId: String, wirdName: String, hour: Int, minute: Int) {
        self.id = id
        self.wirdId = wirdId
        self.wirdName = wirdName
        self.hour = hour
        self.minute = minute
    }
}

/// User-facing preferences for the daily wird reminder.
/// Mirror of Android `WirdReminderPreferences`.
public struct WirdReminderPreferences: Equatable, Sendable, Codable {
    public var enabled: Bool
    /// Local wall-clock hour the reminder fires at. Owner decision: 20:00 — late
    /// enough that "did you do it today?" is a fair question, early enough that
    /// the user can still act on a "no".
    public var hour: Int
    public var minute: Int

    public static let defaultHour = 20
    public static let defaultMinute = 0

    public init(enabled: Bool = true, hour: Int = defaultHour, minute: Int = defaultMinute) {
        self.enabled = enabled
        self.hour = Self.clampHour(hour)
        self.minute = Self.clampMinute(minute)
    }

    static func clampHour(_ value: Int) -> Int { max(0, min(23, value)) }
    static func clampMinute(_ value: Int) -> Int { max(0, min(59, value)) }

    /// Decoding never throws on a bad field: a corrupt blob should cost the user
    /// their chosen time, not their reminders.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        hour = Self.clampHour(try c.decodeIfPresent(Int.self, forKey: .hour) ?? Self.defaultHour)
        minute = Self.clampMinute(try c.decodeIfPresent(Int.self, forKey: .minute) ?? Self.defaultMinute)
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
    public static let notificationReserve = 5

    public static func plan(
        wirds: [Wird],
        preferences: WirdReminderPreferences,
        budget: Int = notificationReserve
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
        return (userCreated + fixed).prefix(budget).map { wird in
            // A fixed slot is asked about while it is still actionable (see
            // `FixedWirdSlot.reminderHour`) rather than piling onto the user's
            // one configured time.
            let slotHour = wird.isFixed ? FixedWirdSlot(wirdId: wird.id)?.reminderHour : nil
            return PlannedWirdReminder(
                id: idPrefix + wird.id,
                wirdId: wird.id,
                wirdName: wird.name,
                hour: slotHour ?? preferences.hour,
                minute: slotHour == nil ? preferences.minute : 0
            )
        }
    }

    /// What is left of a caller's notification budget once the wird reminders
    /// have taken their reservation. Used by the content-reminder scheduler so
    /// there is one subtraction, in one place.
    public static func budgetAfterReserve(_ budget: Int) -> Int {
        max(0, budget - notificationReserve)
    }
}
