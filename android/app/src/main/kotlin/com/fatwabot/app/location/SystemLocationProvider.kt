package com.fatwabot.app.location

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Geocoder
import android.location.LocationManager
import android.os.Build
import androidx.core.content.ContextCompat
import com.fatwabot.feature.prayer.LocationProviding
import com.fatwabot.feature.prayer.LocationState
import com.fatwabot.feature.prayer.ManualCity
import com.fatwabot.feature.prayer.UserLocation
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/**
 * LocationManager-based provider (no Play Services dependency — keeps the app
 * store-agnostic). Caches the last resolve so prayer times paint instantly.
 * Permission requests happen at the UI layer; this provider only reads state.
 */
@Singleton
class SystemLocationProvider @Inject constructor(
    @ApplicationContext private val context: Context,
) : LocationProviding {

    @Serializable
    private data class Cached(
        val lat: Double,
        val lng: Double,
        val name: String,
        val country: String?,
        val manual: Boolean,
    )

    private val prefs = context.getSharedPreferences("prayer_location", Context.MODE_PRIVATE)

    override fun cached(): UserLocation? =
        prefs.getString(KEY, null)?.let { raw ->
            runCatching { Json.decodeFromString<Cached>(raw) }.getOrNull()?.let {
                UserLocation(it.lat, it.lng, it.name, it.country, it.manual)
            }
        }

    override fun setManualCity(city: ManualCity, displayName: String) {
        persist(UserLocation(city.latitude, city.longitude, displayName, city.countryCode, isManual = true))
    }

    override suspend fun resolve(): LocationState {
        cached()?.takeIf { it.isManual }?.let { return LocationState.Resolved(it) }

        if (!hasPermission()) {
            return cached()?.let { LocationState.Resolved(it) } ?: LocationState.Denied
        }
        val manager = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val raw = lastKnown(manager) ?: requestSingleUpdate(manager)
        if (raw == null) {
            return cached()?.let { LocationState.Resolved(it) } ?: LocationState.Denied
        }
        val (name, country) = reverseGeocode(raw.latitude, raw.longitude)
        val location = UserLocation(raw.latitude, raw.longitude, name, country, isManual = false)
        persist(location)
        return LocationState.Resolved(location)
    }

    private fun hasPermission(): Boolean =
        ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED

    @Suppress("MissingPermission")
    private fun lastKnown(manager: LocationManager): android.location.Location? =
        manager.getProviders(true).firstNotNullOfOrNull { provider ->
            runCatching { manager.getLastKnownLocation(provider) }.getOrNull()
        }

    @Suppress("MissingPermission")
    private suspend fun requestSingleUpdate(manager: LocationManager): android.location.Location? =
        withContext(Dispatchers.Main) {
            suspendCancellableCoroutine { continuation ->
                val provider = when {
                    manager.isProviderEnabled(LocationManager.NETWORK_PROVIDER) -> LocationManager.NETWORK_PROVIDER
                    manager.isProviderEnabled(LocationManager.GPS_PROVIDER) -> LocationManager.GPS_PROVIDER
                    else -> {
                        continuation.resume(null) { }
                        return@suspendCancellableCoroutine
                    }
                }
                manager.requestSingleUpdate(provider, { location ->
                    continuation.resume(location) { }
                }, null)
            }
        }

    private suspend fun reverseGeocode(lat: Double, lng: Double): Pair<String, String?> =
        withContext(Dispatchers.IO) {
            runCatching {
                @Suppress("DEPRECATION")
                val place = Geocoder(context).getFromLocation(lat, lng, 1)?.firstOrNull()
                (place?.locality ?: place?.adminArea ?: "") to place?.countryCode
            }.getOrDefault("" to null)
        }

    private fun persist(location: UserLocation) {
        val cachedValue = Cached(
            location.latitude, location.longitude, location.name, location.countryCode, location.isManual,
        )
        prefs.edit().putString(KEY, Json.encodeToString(Cached.serializer(), cachedValue)).apply()
    }

    private companion object {
        const val KEY = "cache"
    }
}
