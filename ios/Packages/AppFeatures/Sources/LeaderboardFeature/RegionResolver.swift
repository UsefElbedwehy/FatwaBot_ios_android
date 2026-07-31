import Foundation

/// The city + country a regional leaderboard ranks you inside.
public struct LeaderboardRegion: Equatable, Sendable {
    public let city: String?
    /// ISO 3166-1 alpha-2, uppercased — the backend normalises to this too.
    public let countryCode: String?

    public init(city: String?, countryCode: String?) {
        self.city = city
        self.countryCode = countryCode
    }

    public static let unknown = LeaderboardRegion(city: nil, countryCode: nil)
}

/// Supplies the region used when joining a country- or city-scope board
/// (owner decision, 2026-07: reuse the prayer-times location).
///
/// ## Why a protocol here and the implementation in the app layer
/// The obvious version reads `LocationProviding` directly — but that lives in
/// `PrayerFeature`, and a leaderboard that imports the prayer feature to learn
/// a city name is exactly the cross-feature dependency ADR-0010 forbids. The
/// app layer already sees both, so the adapter belongs there.
///
/// ## What actually leaves the device
/// Only a city name and a country code, and only when the user joins a regional
/// board. Coordinates are never sent: prayer times are computed on-device
/// (ADR-0003) and this must not quietly become the thing that changes that.
public protocol RegionResolving: Sendable {
    /// The user's region, or `.unknown` when the app has no location — in which
    /// case the join falls back to asking, rather than guessing.
    func currentRegion() async -> LeaderboardRegion
}

/// Used in previews, tests, and any path with no location available.
public struct UnknownRegionResolver: RegionResolving {
    public init() {}
    public func currentRegion() async -> LeaderboardRegion { .unknown }
}

/// Wraps a closure, so the app layer can adapt whatever it already has without
/// this module knowing the shape of it.
public struct ClosureRegionResolver: RegionResolving {
    private let resolve: @Sendable () async -> LeaderboardRegion

    public init(_ resolve: @escaping @Sendable () async -> LeaderboardRegion) {
        self.resolve = resolve
    }

    public func currentRegion() async -> LeaderboardRegion { await resolve() }
}
