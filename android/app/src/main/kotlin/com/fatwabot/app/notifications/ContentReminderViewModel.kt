package com.fatwabot.app.notifications

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.fatwabot.core.content.ContentReminderPreferences
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.datetime.Clock
import java.util.Locale
import javax.inject.Inject

/**
 * Owns the daily azkar/hadith reminder preferences and keeps the alarms in step
 * with them. Mirror of the iOS wiring in `SettingsScreen` + `RootTabView`.
 */
@HiltViewModel
class ContentReminderViewModel @Inject constructor(
    private val store: ContentReminderPreferenceStore,
    private val scheduler: ContentReminderScheduler,
) : ViewModel() {

    fun current(): ContentReminderPreferences = store.load()

    fun update(preferences: ContentReminderPreferences) {
        store.save(preferences)
        // Re-plan immediately so turning it off actually cancels today's pending
        // alarms rather than waiting for the next launch.
        reschedule(preferences)
    }

    /**
     * Safe to call on every launch: the plan is seeded by the day, so
     * re-registering produces the same alarms at the same times.
     */
    fun rescheduleFromStore() = reschedule(store.load())

    private fun reschedule(preferences: ContentReminderPreferences) {
        viewModelScope.launch(Dispatchers.IO) {
            scheduler.ensureChannel()
            scheduler.reschedule(
                preferences = preferences,
                now = Clock.System.now(),
                locale = Locale.getDefault().language,
            )
        }
    }
}
