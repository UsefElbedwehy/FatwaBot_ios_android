import Adhan
import Foundation

/// Thin, deterministic façade over the Adhan implementation. Exists so features
/// and tests depend on our domain vocabulary (method/madhab identifiers as they
/// appear in /v1/config/prayer-defaults), never on the library directly.
public struct PrayerCalculator: Sendable {
    public struct Request: Sendable {
        public let latitude: Double
        public let longitude: Double
        public let date: DateComponents // year/month/day in the location's civil day
        public let method: String
        public let madhab: String
        public let highLatitudeRule: String?

        public init(
            latitude: Double,
            longitude: Double,
            date: DateComponents,
            method: String,
            madhab: String = "shafi",
            highLatitudeRule: String? = nil
        ) {
            self.latitude = latitude
            self.longitude = longitude
            self.date = date
            self.method = method
            self.madhab = madhab
            self.highLatitudeRule = highLatitudeRule
        }
    }

    public struct DayTimes: Equatable, Sendable {
        public let fajr: Date
        public let sunrise: Date
        public let dhuhr: Date
        public let asr: Date
        public let maghrib: Date
        public let isha: Date
    }

    public enum CalculatorError: Error, Equatable {
        case unknownMethod(String)
        case unresolvableTimes
    }

    public init() {}

    /// Server method identifiers (config.prayer_defaults.method) → Adhan parameters.
    static func parameters(method: String) -> CalculationParameters? {
        switch method {
        case "umm_al_qura", "UmmAlQura": CalculationMethod.ummAlQura.params
        case "egyptian", "Egyptian": CalculationMethod.egyptian.params
        case "mwl", "MuslimWorldLeague": CalculationMethod.muslimWorldLeague.params
        case "isna", "NorthAmerica": CalculationMethod.northAmerica.params
        case "karachi", "Karachi": CalculationMethod.karachi.params
        case "dubai", "Dubai": CalculationMethod.dubai.params
        case "turkey", "Turkey": CalculationMethod.turkey.params
        case "singapore", "Singapore": CalculationMethod.singapore.params
        case "kuwait", "Kuwait": CalculationMethod.kuwait.params
        case "qatar", "Qatar": CalculationMethod.qatar.params
        case "moonsighting", "MoonsightingCommittee": CalculationMethod.moonsightingCommittee.params
        default: nil
        }
    }

    public func times(for request: Request) throws -> DayTimes {
        guard var params = Self.parameters(method: request.method) else {
            throw CalculatorError.unknownMethod(request.method)
        }
        params.madhab = request.madhab == "hanafi" ? .hanafi : .shafi
        switch request.highLatitudeRule {
        case "twilight_angle": params.highLatitudeRule = .twilightAngle
        case "seventh_of_the_night": params.highLatitudeRule = .seventhOfTheNight
        case "middle_of_the_night": params.highLatitudeRule = .middleOfTheNight
        default: break
        }

        let coordinates = Coordinates(latitude: request.latitude, longitude: request.longitude)
        guard let prayers = PrayerTimes(coordinates: coordinates, date: request.date, calculationParameters: params) else {
            throw CalculatorError.unresolvableTimes
        }
        return DayTimes(
            fajr: prayers.fajr,
            sunrise: prayers.sunrise,
            dhuhr: prayers.dhuhr,
            asr: prayers.asr,
            maghrib: prayers.maghrib,
            isha: prayers.isha
        )
    }

    /// Great-circle bearing to the Kaaba — the Qibla side of ADR-0003.
    public func qiblaBearing(latitude: Double, longitude: Double) -> Double {
        Qibla(coordinates: Coordinates(latitude: latitude, longitude: longitude)).direction
    }
}
