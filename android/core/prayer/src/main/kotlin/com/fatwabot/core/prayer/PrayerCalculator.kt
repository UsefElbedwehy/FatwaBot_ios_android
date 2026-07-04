package com.fatwabot.core.prayer

import com.batoulapps.adhan2.CalculationMethod
import com.batoulapps.adhan2.CalculationParameters
import com.batoulapps.adhan2.Coordinates
import com.batoulapps.adhan2.HighLatitudeRule
import com.batoulapps.adhan2.Madhab
import com.batoulapps.adhan2.PrayerTimes
import com.batoulapps.adhan2.Qibla
import com.batoulapps.adhan2.data.DateComponents
import kotlinx.datetime.Instant

/**
 * Thin, deterministic façade over the adhan2 implementation — mirror of iOS
 * PrayerKit.PrayerCalculator. Features and tests depend on our domain vocabulary
 * (method/madhab identifiers as served by /v1/config/prayer-defaults), never on
 * the library directly. Both platforms must satisfy the shared golden corpus.
 */
class PrayerCalculator {

    data class Request(
        val latitude: Double,
        val longitude: Double,
        val year: Int,
        val month: Int,
        val day: Int,
        val method: String,
        val madhab: String = "shafi",
        val highLatitudeRule: String? = null,
    )

    data class DayTimes(
        val fajr: Instant,
        val sunrise: Instant,
        val dhuhr: Instant,
        val asr: Instant,
        val maghrib: Instant,
        val isha: Instant,
    )

    class UnknownMethodException(method: String) : IllegalArgumentException("Unknown method: $method")

    fun times(request: Request): DayTimes {
        val base = parameters(request.method) ?: throw UnknownMethodException(request.method)
        val params = base.copy(
            madhab = if (request.madhab == "hanafi") Madhab.HANAFI else Madhab.SHAFI,
            highLatitudeRule = when (request.highLatitudeRule) {
                "twilight_angle" -> HighLatitudeRule.TWILIGHT_ANGLE
                "seventh_of_the_night" -> HighLatitudeRule.SEVENTH_OF_THE_NIGHT
                "middle_of_the_night" -> HighLatitudeRule.MIDDLE_OF_THE_NIGHT
                else -> base.highLatitudeRule
            },
        )
        val prayers = PrayerTimes(
            Coordinates(request.latitude, request.longitude),
            DateComponents(request.year, request.month, request.day),
            params,
        )
        return DayTimes(
            fajr = prayers.fajr,
            sunrise = prayers.sunrise,
            dhuhr = prayers.dhuhr,
            asr = prayers.asr,
            maghrib = prayers.maghrib,
            isha = prayers.isha,
        )
    }

    /** Great-circle bearing to the Kaaba. */
    fun qiblaBearing(latitude: Double, longitude: Double): Double =
        Qibla(Coordinates(latitude, longitude)).direction

    /** Server method identifiers (config.prayer_defaults.method) → adhan2 parameters. */
    private fun parameters(method: String): CalculationParameters? = when (method) {
        "umm_al_qura", "UmmAlQura" -> CalculationMethod.UMM_AL_QURA.parameters
        "egyptian", "Egyptian" -> CalculationMethod.EGYPTIAN.parameters
        "mwl", "MuslimWorldLeague" -> CalculationMethod.MUSLIM_WORLD_LEAGUE.parameters
        "isna", "NorthAmerica" -> CalculationMethod.NORTH_AMERICA.parameters
        "karachi", "Karachi" -> CalculationMethod.KARACHI.parameters
        "dubai", "Dubai" -> CalculationMethod.DUBAI.parameters
        "turkey", "Turkey" -> CalculationMethod.TURKEY.parameters
        "singapore", "Singapore" -> CalculationMethod.SINGAPORE.parameters
        "kuwait", "Kuwait" -> CalculationMethod.KUWAIT.parameters
        "qatar", "Qatar" -> CalculationMethod.QATAR.parameters
        "moonsighting", "MoonsightingCommittee" -> CalculationMethod.MOON_SIGHTING_COMMITTEE.parameters
        else -> null
    }
}
