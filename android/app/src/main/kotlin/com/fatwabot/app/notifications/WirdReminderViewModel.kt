package com.fatwabot.app.notifications

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
) : ViewModel() {

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
            scheduler.reschedule(preferences = preferences, wirds = wirdStore.loadWirds())
        }
    }
}
