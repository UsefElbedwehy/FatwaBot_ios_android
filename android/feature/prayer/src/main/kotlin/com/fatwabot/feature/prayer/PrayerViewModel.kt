package com.fatwabot.feature.prayer

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.fatwabot.core.prayer.HijriDateUi
import com.fatwabot.core.prayer.NextPrayerState
import com.fatwabot.core.prayer.PrayerDayUi
import com.fatwabot.core.prayer.PrayerEngine
import com.fatwabot.core.prayer.PrayerNotificationPreferences
import com.fatwabot.core.prayer.PrayerSettings
import com.fatwabot.core.prayer.PrayerWidgetSnapshot
import com.fatwabot.core.prayer.WidgetSnapshotStore
import dagger.hilt.android.lifecycle.HiltViewModel
import java.time.LocalDate
import java.time.ZoneId
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.datetime.Clock
import kotlinx.datetime.Instant

/** Mirror of iOS PrayerViewModel — state machine for the Prayer surface. */
@HiltViewModel
class PrayerViewModel @Inject constructor(
    private val locationProvider: LocationProviding,
    private val clock: Clock,
    private val scheduler: PrayerNotificationScheduler?,
    private val notificationPreferences: PrayerNotificationPreferences,
    private val widgetStore: WidgetSnapshotStore?,
    private val onWidgetSnapshotWritten: WidgetRefresh?,
) : ViewModel() {

    /** App-supplied hook to trigger Glance updateAll after a new snapshot. */
    fun interface WidgetRefresh {
        fun refresh()
    }

    data class UiState(
        val needsLocation: Boolean = false,
        val location: UserLocation? = null,
        val today: PrayerDayUi? = null,
        val tomorrow: PrayerDayUi? = null,
        val nextPrayer: NextPrayerState? = null,
        val hijri: HijriDateUi? = null,
        val settings: PrayerSettings = PrayerSettings(),
    )

    private val engine = PrayerEngine()
    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init {
        locationProvider.cached()?.let(::apply)
    }

    fun start() {
        viewModelScope.launch {
            when (val resolved = locationProvider.resolve()) {
                is LocationState.Resolved -> {
                    apply(resolved.location)
                    rescheduleNotifications()
                }
                is LocationState.Denied ->
                    if (_state.value.location == null) {
                        _state.value = _state.value.copy(needsLocation = true)
                    }
                LocationState.Unknown -> Unit
            }
        }
    }

    /** Rebuilds the rolling 3-day notification window (parity with iOS). */
    private fun rescheduleNotifications() {
        val scheduler = scheduler ?: return
        val location = _state.value.location ?: return
        val today = localToday()
        val timeline = runCatching {
            engine.timeline(
                location.latitude, location.longitude,
                today.year, today.monthValue, today.dayOfMonth,
                days = 3, settings = _state.value.settings,
            )
        }.getOrNull() ?: return
        scheduler.ensureChannel()
        scheduler.reschedule(timeline, notificationPreferences, clock.now())
    }

    fun selectCity(city: ManualCity, displayName: String) {
        locationProvider.setManualCity(city, displayName)
        apply(
            UserLocation(city.latitude, city.longitude, displayName, city.countryCode, isManual = true),
        )
    }

    fun updateSettings(settings: PrayerSettings) {
        _state.value = _state.value.copy(settings = settings)
        _state.value.location?.let(::apply)
    }

    fun refreshNextPrayer() {
        val current = _state.value
        val today = current.today ?: return
        val tomorrow = current.tomorrow ?: return
        _state.value = current.copy(
            nextPrayer = PrayerEngine.nextPrayer(clock.now(), today, tomorrow),
        )
    }

    fun day(offset: Int): PrayerDayUi? {
        val location = _state.value.location ?: return null
        val date = localToday().plusDays(offset.toLong())
        return runCatching {
            engine.day(
                location.latitude, location.longitude,
                date.year, date.monthValue, date.dayOfMonth, _state.value.settings,
            )
        }.getOrNull()
    }

    private fun localToday(): LocalDate =
        java.time.Instant.ofEpochSecond(clock.now().epochSeconds).atZone(ZoneId.systemDefault()).toLocalDate()

    private fun apply(location: UserLocation) {
        val settings = _state.value.settings
        val today = localToday()
        val days = runCatching {
            engine.timeline(
                location.latitude, location.longitude,
                today.year, today.monthValue, today.dayOfMonth,
                days = 2, settings = settings,
            )
        }.getOrNull() ?: return
        _state.value = _state.value.copy(
            needsLocation = false,
            location = location,
            today = days[0],
            tomorrow = days[1],
            nextPrayer = PrayerEngine.nextPrayer(clock.now(), days[0], days[1]),
            hijri = HijriDateUi.from(today, settings.clampedHijriOffset),
        )
        writeWidgetSnapshot(location, today, settings)
    }

    /** Precomputes a 48h widget snapshot into the shared store (parity with iOS). */
    private fun writeWidgetSnapshot(location: UserLocation, today: LocalDate, settings: PrayerSettings) {
        val store = widgetStore ?: return
        val timeline = runCatching {
            engine.timeline(
                location.latitude, location.longitude,
                today.year, today.monthValue, today.dayOfMonth,
                days = 3, settings = settings,
            )
        }.getOrNull() ?: return
        val snapshot = PrayerWidgetSnapshot.build(
            timeline = timeline,
            location = location.name,
            hijri = HijriDateUi.from(today, settings.clampedHijriOffset),
            generatedAtEpochSeconds = clock.now().epochSeconds,
        )
        store.write(snapshot)
        onWidgetSnapshotWritten?.refresh()
    }
}
