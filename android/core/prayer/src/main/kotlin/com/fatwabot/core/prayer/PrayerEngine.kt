package com.fatwabot.core.prayer

import java.time.LocalDate
import java.time.chrono.HijrahChronology
import java.time.format.DateTimeFormatter
import java.util.Locale
import kotlinx.datetime.Instant

/** User-facing prayer names. SUNRISE is displayed but is not a prayer. */
enum class PrayerNameUi(val isPrayer: Boolean) {
    FAJR(true), SUNRISE(false), DHUHR(true), ASR(true), MAGHRIB(true), ISHA(true)
}

/**
 * Resolved calculation settings — mirror of iOS PrayerKit.PrayerSettings.
 * Defaults flow: user override → /v1/config/prayer-defaults(country) → bundled fallback.
 */
data class PrayerSettings(
    // Umm al-Qura is the bundled default (stakeholder direction, 2026-07-12):
    // matches the Saudi authority users compare against, and is the offline
    // fallback whenever server config (which can override per country) is absent.
    val method: String = "umm_al_qura",
    val madhab: String = "shafi",
    /** null = automatic: recommended rule ≥48° (spike policy), none below. */
    val highLatitudeRule: String? = null,
    val adjustmentsMinutes: Map<PrayerNameUi, Int> = emptyMap(),
    val hijriOffsetDays: Int = 0,
) {
    val clampedAdjustments: Map<PrayerNameUi, Int>
        get() = adjustmentsMinutes.mapValues { it.value.coerceIn(-30, 30) }
    val clampedHijriOffset: Int
        get() = hijriOffsetDays.coerceIn(-2, 2)

    companion object {
        const val HIGH_LATITUDE_THRESHOLD = 48.0
    }
}

/** One civil day's times, adjustments applied. */
data class PrayerDayUi(
    val year: Int,
    val month: Int,
    val day: Int,
    val times: Map<PrayerNameUi, Instant>,
) {
    val ordered: List<Pair<PrayerNameUi, Instant>>
        get() = PrayerNameUi.entries.map { it to times.getValue(it) }
}

data class NextPrayerState(
    val current: PrayerNameUi?,
    val next: PrayerNameUi,
    val nextTime: Instant,
)

/** Deterministic engine over PrayerCalculator — mirror of iOS PrayerEngine. */
class PrayerEngine(private val calculator: PrayerCalculator = PrayerCalculator()) {

    fun day(
        latitude: Double,
        longitude: Double,
        year: Int,
        month: Int,
        dayOfMonth: Int,
        settings: PrayerSettings,
    ): PrayerDayUi {
        val rule = effectiveHighLatitudeRule(settings, latitude)
        val raw = calculator.times(
            PrayerCalculator.Request(
                latitude = latitude, longitude = longitude,
                year = year, month = month, day = dayOfMonth,
                method = settings.method, madhab = settings.madhab,
                highLatitudeRule = rule,
            ),
        )
        val base = mapOf(
            PrayerNameUi.FAJR to raw.fajr,
            PrayerNameUi.SUNRISE to raw.sunrise,
            PrayerNameUi.DHUHR to raw.dhuhr,
            PrayerNameUi.ASR to raw.asr,
            PrayerNameUi.MAGHRIB to raw.maghrib,
            PrayerNameUi.ISHA to raw.isha,
        )
        val adjustments = settings.clampedAdjustments
        val times = base.mapValues { (name, instant) ->
            val minutes = adjustments[name] ?: 0
            if (minutes == 0) instant else Instant.fromEpochSeconds(instant.epochSeconds + minutes * 60L)
        }
        return PrayerDayUi(year, month, dayOfMonth, times)
    }

    fun timeline(
        latitude: Double,
        longitude: Double,
        startYear: Int,
        startMonth: Int,
        startDay: Int,
        days: Int,
        settings: PrayerSettings,
    ): List<PrayerDayUi> {
        val start = LocalDate.of(startYear, startMonth, startDay)
        return (0 until days).map { offset ->
            val date = start.plusDays(offset.toLong())
            day(latitude, longitude, date.year, date.monthValue, date.dayOfMonth, settings)
        }
    }

    companion object {
        /**
         * Spike policy: explicit config rule wins; ≥48° with no rule → recommended,
         * never the library default. Recommendation logic mirrors adhan-swift's
         * HighLatitudeRule.recommended(for:): above 48° → seventh of the night.
         */
        fun effectiveHighLatitudeRule(settings: PrayerSettings, latitude: Double): String? {
            settings.highLatitudeRule?.let { return it }
            if (kotlin.math.abs(latitude) < PrayerSettings.HIGH_LATITUDE_THRESHOLD) return null
            return "seventh_of_the_night"
        }

        /** Next-prayer resolution across day boundaries; SUNRISE is never "next". */
        fun nextPrayer(now: Instant, today: PrayerDayUi, tomorrow: PrayerDayUi): NextPrayerState {
            val prayers = today.ordered.filter { it.first.isPrayer }
            val upcoming = prayers.firstOrNull { it.second > now }
            if (upcoming != null) {
                val current = prayers.lastOrNull { it.second <= now }?.first
                return NextPrayerState(current, upcoming.first, upcoming.second)
            }
            return NextPrayerState(
                PrayerNameUi.ISHA, PrayerNameUi.FAJR, tomorrow.times.getValue(PrayerNameUi.FAJR),
            )
        }
    }
}

/** Hijri date with offset — java.time HijrahChronology (Umm al-Qura). */
data class HijriDateUi(val year: Int, val month: Int, val day: Int, val monthName: String) {
    companion object {
        fun from(date: LocalDate, offsetDays: Int, locale: Locale = Locale("ar")): HijriDateUi {
            val hijrah = HijrahChronology.INSTANCE.date(date.plusDays(offsetDays.toLong()))
            val monthName = DateTimeFormatter.ofPattern("MMMM", locale).format(hijrah)
            return HijriDateUi(
                year = hijrah.get(java.time.temporal.ChronoField.YEAR),
                month = hijrah.get(java.time.temporal.ChronoField.MONTH_OF_YEAR),
                day = hijrah.get(java.time.temporal.ChronoField.DAY_OF_MONTH),
                monthName = monthName,
            )
        }
    }
}
