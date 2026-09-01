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
/**
 * Days of prayer times laid out for the notification schedule.
 *
 * Was 3, which silently capped the horizon: the planner had a large budget but
 * was only ever handed three days of times, so no amount of allocation work
 * could reach past day three. AlarmManager has no pending-alarm cap, so Android
 * can carry a much longer window than iOS; the arithmetic is pure and cheap.
 */
private const val NOTIFICATION_HORIZON_DAYS = 30

@HiltViewModel
class PrayerViewModel @Inject constructor(
    private val locationProvider: LocationProviding,
    private val clock: Clock,
    private val scheduler: PrayerNotificationScheduler?,
    private val notificationPreferenceStore: NotificationPreferenceStore?,
    private val widgetStore: WidgetSnapshotStore?,
    private val onWidgetSnapshotWritten: WidgetRefresh?,
) : ViewModel() {

    /** User's notification preferences (per-type toggles + offsets); editable
     * from Settings and persisted via [notificationPreferenceStore]. */
    private var notificationPreferences: PrayerNotificationPreferences =
        notificationPreferenceStore?.load() ?: PrayerNotificationPreferences()

    fun currentNotificationPreferences(): PrayerNotificationPreferences = notificationPreferences

    /** Persist edited preferences and rebuild the schedule. */
    fun updateNotificationPreferences(preferences: PrayerNotificationPreferences) {
        notificationPreferences = preferences
        notificationPreferenceStore?.save(preferences)
        rescheduleNotifications()
    }

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
        // Instant first paint from cache; start() refines asynchronously and
        // re-applies with updateWidget = true — skip the widget-snapshot
        // write (disk write + updateAll IPC) here so it isn't on the
        // synchronous cold-start path.
        locationProvider.cached()?.let { apply(it, updateWidget = false) }
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
        val today = localToday(location.zoneId)
        val timeline = runCatching {
            engine.timeline(
                location.latitude, location.longitude,
                today.year, today.monthValue, today.dayOfMonth,
                days = NOTIFICATION_HORIZON_DAYS, settings = _state.value.settings,
            )
        }.getOrNull() ?: return
        scheduler.ensureChannel()
        scheduler.reschedule(timeline, notificationPreferences, clock.now())
    }

    fun selectCity(city: ManualCity, displayName: String) {
        locationProvider.setManualCity(city, displayName)
        apply(
            UserLocation(
                city.latitude, city.longitude, displayName, city.countryCode,
                isManual = true, timeZone = city.timeZone,
            ),
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
        val date = localToday(location.zoneId).plusDays(offset.toLong())
        return runCatching {
            engine.day(
                location.latitude, location.longitude,
                date.year, date.monthValue, date.dayOfMonth, _state.value.settings,
            )
        }.getOrNull()
    }

    private fun localToday(zone: ZoneId): LocalDate =
        java.time.Instant.ofEpochSecond(clock.now().epochSeconds).atZone(zone).toLocalDate()

    private fun apply(location: UserLocation, updateWidget: Boolean = true) {
        val settings = _state.value.settings
        val today = localToday(location.zoneId)
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
        if (updateWidget) {
            writeWidgetSnapshot(location, today, settings)
        }
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
            timeZoneId = location.timeZone?.id,
        )
        store.write(snapshot)
        onWidgetSnapshotWritten?.refresh()
    }
}

/** The zone prayer times should be computed and displayed in for this
 *  location, falling back to the device's own timezone if none resolved. */
val UserLocation.zoneId: ZoneId get() = timeZone?.toZoneId() ?: ZoneId.systemDefault()
