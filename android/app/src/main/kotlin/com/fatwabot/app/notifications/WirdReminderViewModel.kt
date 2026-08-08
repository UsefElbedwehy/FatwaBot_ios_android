package com.fatwabot.app.notifications

import com.fatwabot.core.prayer.PrayerEngine
import com.fatwabot.core.prayer.PrayerNameUi
import com.fatwabot.core.prayer.PrayerSettings
import com.fatwabot.feature.awrad.WirdReminderPlanner
import com.fatwabot.feature.prayer.LocationProviding
import java.time.LocalDate
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.fatwabot.feature.awrad.WirdReminderPreferences
import com.fatwabot.feature.awrad.WirdStoring
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/**
 * Owns the daily wird reminder preferences and keeps the alarms in step with
 * them. Mirror of the iOS wiring in `SettingsScreen` + `RootTabView`.
 */
@HiltViewModel
class WirdReminderViewModel @Inject constructor(
    private val store: WirdReminderPreferenceStore,
    private val wirdStore: WirdStoring,
    private val scheduler: WirdReminderScheduler,
    private val locationProvider: LocationProviding,
) : ViewModel() {

    /**
     * Prayer times for the anchored wirds, from the *cached* location only.
     *
     * `cached()` rather than `resolve()` on purpose: rescheduling runs on every
     * launch and on every settings change, and resolving would mean a location
     * request each time — a permission prompt in the worst case. With no cached
     * location the planner falls back to clock times, which is the designed
     * behaviour rather than a failure.
     */
    private val prayerTimes = WirdReminderPlanner.PrayerTimeLookup { dayOffset, prayer ->
        val location = locationProvider.cached() ?: return@PrayerTimeLookup null
        val name = PrayerNameUi.entries.firstOrNull { it.key == prayer }
            ?: return@PrayerTimeLookup null
        val day = LocalDate.now().plusDays(dayOffset.toLong())
        runCatching {
            PrayerEngine().timeline(
                location.latitude, location.longitude,
                day.year, day.monthValue, day.dayOfMonth, 1,
                PrayerSettings(),
            ).firstOrNull()?.times?.get(name)?.epochSeconds?.times(1000L)
        }.getOrNull()
    }

    fun current(): WirdReminderPreferences = store.load()

    fun update(preferences: WirdReminderPreferences) {
        store.save(preferences)
        // Re-plan immediately so turning it off actually cancels pending alarms,
        // and a new time moves them, rather than waiting for the next launch.
        reschedule(preferences)
    }

    /**
     * Safe to call on every launch: ids are derived from the wird ids and the
     * time is fixed, so re-registering lands on the same alarms. Also how a wird
     * created or archived since the last launch gains or loses its reminder.
     */
    fun rescheduleFromStore() = reschedule(store.load())

    private fun reschedule(preferences: WirdReminderPreferences) {
        viewModelScope.launch(Dispatchers.IO) {
            scheduler.ensureChannel()
            scheduler.reschedule(
                preferences = preferences,
                wirds = wirdStore.loadWirds(),
                prayerTime = prayerTimes,
            )
        }
    }
}
