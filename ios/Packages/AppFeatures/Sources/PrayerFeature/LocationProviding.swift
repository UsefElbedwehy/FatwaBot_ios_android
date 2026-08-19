import CoreLocation
import Foundation

public struct UserLocation: Equatable, Sendable {
    public let latitude: Double
    public let longitude: Double
    /// Display name (reverse-geocoded locality or manual city name).
    public let name: String
    public let countryCode: String?
    public let isManual: Bool
    /// The location's own timezone — from `CLPlacemark` on the GPS path, from
    /// `ManualCity.timeZoneIdentifier` on the manual path. `nil` only if
    /// reverse-geocoding didn't return one; callers fall back to the device's.
    ///
    /// Prayer times must be computed and displayed in *this* timezone, not the
    /// device's: picking Makkah while the device is still set to New York time
    /// should show Makkah's local Fajr, not a device-timezone translation of
    /// the same instant several hours off.
    public let timeZone: TimeZone?

    public init(
        latitude: Double, longitude: Double, name: String, countryCode: String?, isManual: Bool,
        timeZone: TimeZone? = nil
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.name = name
        self.countryCode = countryCode
        self.isManual = isManual
        self.timeZone = timeZone
    }
}

public enum LocationState: Equatable, Sendable {
    case unknown          // first launch, nothing yet
    case resolved(UserLocation)
    case denied           // permission denied → manual city picker path
}

public protocol LocationProviding: Sendable {
    /// Last known (cached) location — synchronous, drives instant first paint.
    func cached() -> UserLocation?
    /// Request permission if needed and resolve a fresh location.
    func resolve() async -> LocationState
}

/// Bundled manual-city fallback (the app must be fully usable with location
/// denied — docs/features/prayer.md). Content-managed list arrives in M2.
public struct ManualCity: Identifiable, Equatable, Sendable {
    public let id: String
    public let nameKey: String   // localized via string packs
    public let latitude: Double
    public let longitude: Double
    public let countryCode: String
    /// IANA identifier — hardcoded rather than reverse-geocoded, since the
    /// point of the manual-city path is working with no location services at
    /// all. Each of these 12 has one real, unambiguous timezone.
    public let timeZoneIdentifier: String

    public var timeZone: TimeZone? { TimeZone(identifier: timeZoneIdentifier) }

    public static let bundled: [ManualCity] = [
        ManualCity(id: "makkah", nameKey: "city.makkah", latitude: 21.4225, longitude: 39.8262, countryCode: "SA", timeZoneIdentifier: "Asia/Riyadh"),
        ManualCity(id: "madinah", nameKey: "city.madinah", latitude: 24.4672, longitude: 39.6111, countryCode: "SA", timeZoneIdentifier: "Asia/Riyadh"),
        ManualCity(id: "riyadh", nameKey: "city.riyadh", latitude: 24.7136, longitude: 46.6753, countryCode: "SA", timeZoneIdentifier: "Asia/Riyadh"),
        ManualCity(id: "cairo", nameKey: "city.cairo", latitude: 30.0444, longitude: 31.2357, countryCode: "EG", timeZoneIdentifier: "Africa/Cairo"),
        ManualCity(id: "dubai", nameKey: "city.dubai", latitude: 25.2048, longitude: 55.2708, countryCode: "AE", timeZoneIdentifier: "Asia/Dubai"),
        ManualCity(id: "istanbul", nameKey: "city.istanbul", latitude: 41.0082, longitude: 28.9784, countryCode: "TR", timeZoneIdentifier: "Europe/Istanbul"),
        ManualCity(id: "london", nameKey: "city.london", latitude: 51.5074, longitude: -0.1278, countryCode: "GB", timeZoneIdentifier: "Europe/London"),
        ManualCity(id: "newyork", nameKey: "city.newyork", latitude: 40.7128, longitude: -74.006, countryCode: "US", timeZoneIdentifier: "America/New_York"),
        ManualCity(id: "jakarta", nameKey: "city.jakarta", latitude: -6.2088, longitude: 106.8456, countryCode: "ID", timeZoneIdentifier: "Asia/Jakarta"),
        ManualCity(id: "kualalumpur", nameKey: "city.kualalumpur", latitude: 3.139, longitude: 101.6869, countryCode: "MY", timeZoneIdentifier: "Asia/Kuala_Lumpur"),
        ManualCity(id: "karachi", nameKey: "city.karachi", latitude: 24.8607, longitude: 67.0011, countryCode: "PK", timeZoneIdentifier: "Asia/Karachi"),
        ManualCity(id: "casablanca", nameKey: "city.casablanca", latitude: 33.5731, longitude: -7.5898, countryCode: "MA", timeZoneIdentifier: "Africa/Casablanca"),
    ]
}

/// CoreLocation-backed provider. Caches the last resolve in UserDefaults so
/// prayer times paint instantly on every subsequent launch.
public final class SystemLocationProvider: NSObject, LocationProviding, @unchecked Sendable {
    private static let cacheKey = "prayer.location.cache"
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<LocationState, Never>?
    private var timeoutTask: Task<Void, Never>?

    /// How long to wait for CoreLocation before giving up.
    ///
    /// Neither `requestLocation()` nor the authorization callback is guaranteed
    /// to fire: with no fix available — a simulator with no location set, a
    /// device indoors, permission granted but hardware unable — the delegate is
    /// simply never called and `withCheckedContinuation` waits forever. That
    /// stranded onboarding on a spinner with no way forward but "Not now".
    ///
    /// 12s is past a normal cold GPS acquire, so this fires on genuine failure
    /// rather than on a slow success.
    private static let resolveTimeout: Duration = .seconds(12)

    /// Resumes exactly once. Every path — delegate callback or timeout — goes
    /// through here, because resuming a continuation twice is a crash, not a
    /// warning.
    private func finish(_ state: LocationState) {
        timeoutTask?.cancel()
        timeoutTask = nil
        guard let pending = continuation else { return }
        continuation = nil
        pending.resume(returning: state)
    }

    /// Arms the timeout for a continuation that has just been stored.
    private func armTimeout() {
        timeoutTask?.cancel()
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(for: Self.resolveTimeout)
            guard !Task.isCancelled, let self else { return }
            // A previously cached fix beats nothing; otherwise `.unknown` lets
            // the caller offer the manual city picker, which already exists.
            self.finish(self.cached().map { .resolved($0) } ?? .unknown)
        }
    }
    /// True only while `resolve()` is waiting on a `.notDetermined` → answered
    /// transition — guards `locationManagerDidChangeAuthorization` so it only
    /// acts during that specific window (that delegate method fires for other
    /// reasons too, e.g. on `init`).
    private var awaitingAuthorization = false
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    public func cached() -> UserLocation? {
        guard let data = defaults.data(forKey: Self.cacheKey) else { return nil }
        return try? JSONDecoder().decode(CachedLocation.self, from: data).toUserLocation()
    }

    public func setManualCity(_ city: ManualCity, displayName: String) {
        let location = UserLocation(
            latitude: city.latitude, longitude: city.longitude,
            name: displayName, countryCode: city.countryCode, isManual: true,
            timeZone: city.timeZone
        )
        persist(location)
    }

    public func resolve() async -> LocationState {
        if let manual = cached(), manual.isManual {
            return .resolved(manual) // manual choice wins until user changes it
        }
        switch manager.authorizationStatus {
        case .denied, .restricted:
            return cached().map { .resolved($0) } ?? .denied
        case .notDetermined:
            // requestLocation() is a no-op while authorization is undetermined
            // — must wait for the OS dialog to actually resolve first (via
            // locationManagerDidChangeAuthorization) before requesting a fix,
            // or the continuation would never be resumed (this used to hang
            // "Allow" on the onboarding location screen forever).
            return await withCheckedContinuation { continuation in
                self.continuation = continuation
                self.awaitingAuthorization = true
                self.armTimeout()
                manager.requestWhenInUseAuthorization()
            }
        default:
            return await withCheckedContinuation { continuation in
                self.continuation = continuation
                self.armTimeout()
                manager.requestLocation()
            }
        }
    }

    private func persist(_ location: UserLocation) {
        if let data = try? JSONEncoder().encode(CachedLocation(from: location)) {
            defaults.set(data, forKey: Self.cacheKey)
        }
    }

    private struct CachedLocation: Codable {
        let lat: Double
        let lng: Double
        let name: String
        let country: String?
        let manual: Bool
        let timeZoneIdentifier: String?

        init(from location: UserLocation) {
            lat = location.latitude
            lng = location.longitude
            name = location.name
            country = location.countryCode
            manual = location.isManual
            timeZoneIdentifier = location.timeZone?.identifier
        }

        func toUserLocation() -> UserLocation {
            UserLocation(
                latitude: lat, longitude: lng, name: name, countryCode: country, isManual: manual,
                timeZone: timeZoneIdentifier.flatMap(TimeZone.init(identifier:))
            )
        }
    }
}

extension SystemLocationProvider: CLLocationManagerDelegate {
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let raw = locations.last else { return }
        Task { [weak self] in
            guard let self else { return }
            let placemark = try? await CLGeocoder().reverseGeocodeLocation(raw).first
            let location = UserLocation(
                latitude: raw.coordinate.latitude,
                longitude: raw.coordinate.longitude,
                name: placemark?.locality ?? placemark?.administrativeArea ?? "",
                countryCode: placemark?.isoCountryCode,
                isManual: false,
                timeZone: placemark?.timeZone
            )
            self.persist(location)
            self.finish(.resolved(location))
        }
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let state: LocationState = cached().map { .resolved($0) } ?? .denied
        finish(state)
    }

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard awaitingAuthorization else { return }
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            // Now safe to request a fix — didUpdateLocations/didFailWithError
            // will resume the continuation.
            awaitingAuthorization = false
            manager.requestLocation()
        case .denied, .restricted:
            awaitingAuthorization = false
            let state: LocationState = cached().map { .resolved($0) } ?? .denied
            finish(state)
        case .notDetermined:
            break // still waiting on the OS dialog
        @unknown default:
            awaitingAuthorization = false
            let state: LocationState = cached().map { .resolved($0) } ?? .denied
            finish(state)
        }
    }
}
