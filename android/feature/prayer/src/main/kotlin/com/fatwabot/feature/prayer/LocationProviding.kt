package com.fatwabot.feature.prayer

import java.util.TimeZone

data class UserLocation(
    val latitude: Double,
    val longitude: Double,
    val name: String,
    val countryCode: String?,
    val isManual: Boolean,
    /**
     * The location's own timezone — hardcoded per [ManualCity] on the manual
     * path, best-effort-resolved from the country code on the GPS path (see
     * `SystemLocationProvider`). `null` only when neither could resolve one;
     * callers fall back to the device's timezone.
     *
     * Prayer times must be computed and displayed in *this* timezone, not the
     * device's: picking Makkah while the device is still set to New York time
     * should show Makkah's local Fajr, not a device-timezone translation of
     * the same instant several hours off.
     */
    val timeZone: TimeZone? = null,
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
    /** IANA identifier — hardcoded rather than resolved, since the point of
     *  the manual-city path is working with no location services at all.
     *  Each of these 12 has one real, unambiguous timezone. Mirrors iOS
     *  `ManualCity.timeZoneIdentifier`. */
    val timeZoneId: String,
) {
    val timeZone: TimeZone get() = TimeZone.getTimeZone(timeZoneId)

    companion object {
        val bundled = listOf(
            ManualCity("makkah", "city_makkah", 21.4225, 39.8262, "SA", "Asia/Riyadh"),
            ManualCity("madinah", "city_madinah", 24.4672, 39.6111, "SA", "Asia/Riyadh"),
            ManualCity("riyadh", "city_riyadh", 24.7136, 46.6753, "SA", "Asia/Riyadh"),
            ManualCity("cairo", "city_cairo", 30.0444, 31.2357, "EG", "Africa/Cairo"),
            ManualCity("dubai", "city_dubai", 25.2048, 55.2708, "AE", "Asia/Dubai"),
            ManualCity("istanbul", "city_istanbul", 41.0082, 28.9784, "TR", "Europe/Istanbul"),
            ManualCity("london", "city_london", 51.5074, -0.1278, "GB", "Europe/London"),
            ManualCity("newyork", "city_newyork", 40.7128, -74.006, "US", "America/New_York"),
            ManualCity("jakarta", "city_jakarta", -6.2088, 106.8456, "ID", "Asia/Jakarta"),
            ManualCity("kualalumpur", "city_kualalumpur", 3.139, 101.6869, "MY", "Asia/Kuala_Lumpur"),
            ManualCity("karachi", "city_karachi", 24.8607, 67.0011, "PK", "Asia/Karachi"),
            ManualCity("casablanca", "city_casablanca", 33.5731, -7.5898, "MA", "Africa/Casablanca"),
        )
    }
}
