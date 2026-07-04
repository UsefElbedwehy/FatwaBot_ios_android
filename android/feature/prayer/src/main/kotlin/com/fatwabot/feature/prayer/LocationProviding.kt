package com.fatwabot.feature.prayer

data class UserLocation(
    val latitude: Double,
    val longitude: Double,
    val name: String,
    val countryCode: String?,
    val isManual: Boolean,
)

sealed interface LocationState {
    data object Unknown : LocationState
    data class Resolved(val location: UserLocation) : LocationState
    data object Denied : LocationState
}

/** Mirror of iOS LocationProviding. System impl (FusedLocation) lands with app wiring. */
interface LocationProviding {
    fun cached(): UserLocation?
    suspend fun resolve(): LocationState
    fun setManualCity(city: ManualCity, displayName: String)
}

/** Bundled manual-city fallback — same list as iOS until M2 content sync. */
data class ManualCity(
    val id: String,
    val nameKey: String,
    val latitude: Double,
    val longitude: Double,
    val countryCode: String,
) {
    companion object {
        val bundled = listOf(
            ManualCity("makkah", "city_makkah", 21.4225, 39.8262, "SA"),
            ManualCity("madinah", "city_madinah", 24.4672, 39.6111, "SA"),
            ManualCity("riyadh", "city_riyadh", 24.7136, 46.6753, "SA"),
            ManualCity("cairo", "city_cairo", 30.0444, 31.2357, "EG"),
            ManualCity("dubai", "city_dubai", 25.2048, 55.2708, "AE"),
            ManualCity("istanbul", "city_istanbul", 41.0082, 28.9784, "TR"),
            ManualCity("london", "city_london", 51.5074, -0.1278, "GB"),
            ManualCity("newyork", "city_newyork", 40.7128, -74.006, "US"),
            ManualCity("jakarta", "city_jakarta", -6.2088, 106.8456, "ID"),
            ManualCity("kualalumpur", "city_kualalumpur", 3.139, 101.6869, "MY"),
            ManualCity("karachi", "city_karachi", 24.8607, 67.0011, "PK"),
            ManualCity("casablanca", "city_casablanca", 33.5731, -7.5898, "MA"),
        )
    }
}
