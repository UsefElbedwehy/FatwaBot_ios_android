import Foundation

/// The deeds the متابعة العبادات tracker can log.
///
/// Shared between the widget (which writes them) and the app (which drains and
/// uploads them) so the two cannot drift: a widget writing `"azkar_morning"`
/// against an app expecting `"morning_azkar"` would log deeds that silently
/// never count toward a streak.
public enum WorshipDeed: String, CaseIterable, Codable, Sendable {
    case fajr, dhuhr, asr, maghrib, isha
    case azkarMorning = "azkar_morning"
    case azkarEvening = "azkar_evening"

    /// The five obligatory prayers, in order.
    public static let prayers: [WorshipDeed] = [.fajr, .dhuhr, .asr, .maghrib, .isha]

    /// The event type this deed is submitted as, matching what the app already
    /// records from its own screens — so a prayer logged from the widget and one
    /// logged in-app are indistinguishable to the streak engine.
    public var eventType: String {
        switch self {
        case .azkarMorning, .azkarEvening: "azkar_completed"
        default: "prayer_completed"
        }
    }

    public var metadata: [String: String] {
        switch self {
        case .azkarMorning: ["category": "morning"]
        case .azkarEvening: ["category": "evening"]
        default: ["prayer": rawValue]
        }
    }

    /// Localization key for the tile label.
    public var titleKey: String {
        switch self {
        case .azkarMorning: "deed.azkar_morning"
        case .azkarEvening: "deed.azkar_evening"
        default: "prayer.\(rawValue)"
        }
    }

    public var symbolName: String {
        switch self {
        case .fajr: "sunrise"
        case .dhuhr: "sun.max"
        case .asr: "cloud.sun"
        case .maghrib: "sunset"
        case .isha: "moon.stars"
        case .azkarMorning: "leaf"
        case .azkarEvening: "moon"
        }
    }
}
