import Foundation
import Observation
import PrayerKit

/// State machine for the Prayer surface (screen + Home hero share it).
/// Pure over injected dependencies; all effects owned here, never in views.
@MainActor
@Observable
public final class PrayerViewModel {
    public enum Status: Equatable {
        case needsLocation           // denied + no cache → manual city path
        case ready
    }

    public private(set) var status: Status = .ready
    public private(set) var location: UserLocation?
    public private(set) var today: PrayerDay?
    public private(set) var tomorrow: PrayerDay?
    public private(set) var nextPrayer: NextPrayerState?
    public private(set) var hijri: HijriDate?
    public private(set) var settings: PrayerSettings

    private let engine: PrayerEngine
    private let locationProvider: LocationProviding
    private let now: @Sendable () -> Date
    private let calendar: Calendar

    public init(
        engine: PrayerEngine = PrayerEngine(),
        locationProvider: LocationProviding,
        settings: PrayerSettings = PrayerSettings(),
        now: @escaping @Sendable () -> Date = { Date() },
        calendar: Calendar = .current
    ) {
        self.engine = engine
        self.locationProvider = locationProvider
        self.settings = settings
        self.now = now
        self.calendar = calendar
        // Instant first paint from cache; resolve() refines asynchronously.
        if let cached = locationProvider.cached() {
            apply(location: cached)
        }
    }

    public func start() async {
        switch await locationProvider.resolve() {
        case .resolved(let location):
            apply(location: location)
        case .denied:
            if location == nil { status = .needsLocation }
        case .unknown:
            break
        }
    }

    public func select(city: ManualCity, displayName: String) {
        (locationProvider as? SystemLocationProvider)?.setManualCity(city, displayName: displayName)
        apply(location: UserLocation(
            latitude: city.latitude, longitude: city.longitude,
            name: displayName, countryCode: city.countryCode, isManual: true
        ))
    }

    public func update(settings: PrayerSettings) {
        self.settings = settings
        if let location { apply(location: location) }
    }

    /// Recompute countdown state (call on timer tick / foreground).
    public func refreshNextPrayer() {
        guard let today, let tomorrow else { return }
        nextPrayer = PrayerEngine.nextPrayer(now: now(), today: today, tomorrow: tomorrow)
    }

    public func day(offset: Int) -> PrayerDay? {
        guard let location else { return nil }
        let date = calendar.date(byAdding: .day, value: offset, to: now())!
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return try? engine.day(
            latitude: location.latitude, longitude: location.longitude,
            date: components, settings: settings
        )
    }

    private func apply(location: UserLocation) {
        self.location = location
        self.status = .ready
        let currentDate = now()
        let todayComponents = calendar.dateComponents([.year, .month, .day], from: currentDate)
        guard let days = try? engine.timeline(
            latitude: location.latitude, longitude: location.longitude,
            startDate: todayComponents, days: 2, settings: settings, calendar: calendar
        ), days.count == 2 else { return }
        today = days[0]
        tomorrow = days[1]
        nextPrayer = PrayerEngine.nextPrayer(now: currentDate, today: days[0], tomorrow: days[1])
        hijri = HijriDate(from: currentDate, offsetDays: settings.hijriOffsetDays)
    }
}
