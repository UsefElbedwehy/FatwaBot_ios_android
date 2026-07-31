package com.fatwabot.feature.leaderboard

/** The city + country a regional leaderboard ranks you inside. */
data class LeaderboardRegion(
    val city: String? = null,
    /** ISO 3166-1 alpha-2, uppercased — the backend normalises to this too. */
    val countryCode: String? = null,
) {
    companion object {
        val Unknown = LeaderboardRegion()
    }
}

/**
 * Supplies the region used when joining a country- or city-scope board
 * (owner decision, 2026-07: reuse the prayer-times location). Mirror of iOS
 * `RegionResolving`.
 *
 * ## Why a seam here and the implementation in the app module
 * The obvious version reads `LocationProviding` directly — but that lives in
 * `:feature:prayer`, and a leaderboard that depends on the prayer feature to
 * learn a city name is exactly the cross-feature dependency ADR-0010 forbids.
 * The app module already sees both, so the binding belongs there.
 *
 * ## What actually leaves the device
 * Only a city name and a country code, and only when the user joins a regional
 * board. Coordinates are never sent: prayer times are computed on-device
 * (ADR-0003), and this must not quietly become the thing that changes that.
 */
fun interface RegionResolving {
    /**
     * The user's region, or [LeaderboardRegion.Unknown] when the app has no
     * location — in which case the join falls back to asking, not guessing.
     */
    suspend fun currentRegion(): LeaderboardRegion
}

/** Used in previews, tests, and any path with no location available. */
class UnknownRegionResolver : RegionResolving {
    override suspend fun currentRegion(): LeaderboardRegion = LeaderboardRegion.Unknown
}
