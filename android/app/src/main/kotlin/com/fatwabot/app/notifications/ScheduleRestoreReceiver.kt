package com.fatwabot.app.notifications

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.fatwabot.core.prayer.PrayerEngine
import com.fatwabot.core.prayer.PrayerSettings
import com.fatwabot.feature.awrad.WirdStoring
import com.fatwabot.feature.prayer.LocationProviding
import com.fatwabot.feature.prayer.NotificationPreferenceStore
import com.fatwabot.feature.prayer.PrayerNotificationScheduler
import dagger.hilt.EntryPoint
import dagger.hilt.InstallIn
import dagger.hilt.android.EntryPointAccessors
import dagger.hilt.components.SingletonComponent
import java.time.LocalDate
import kotlinx.datetime.Clock

/** See the note on `WirdSchedulerEntryPoint`: BroadcastReceivers cannot be
 *  `@AndroidEntryPoint` field-injected here, so dependencies are pulled. */
@EntryPoint
@InstallIn(SingletonComponent::class)
private interface ScheduleRestoreEntryPoint {
    fun prayerNotificationScheduler(): PrayerNotificationScheduler
    fun notificationPreferenceStore(): NotificationPreferenceStore
    fun locationProvider(): LocationProviding
    fun wirdReminderScheduler(): WirdReminderScheduler
    fun wirdReminderPreferenceStore(): WirdReminderPreferenceStore
    fun wirdStore(): WirdStoring
}

/**
 * Rebuilds the alarm schedule after the system throws it away.
 *
 * ## Why this exists
 * **AlarmManager loses every alarm on reboot.** The manifest has declared
 * `RECEIVE_BOOT_COMPLETED` since the beginning, but nothing ever listened for
 * it — so a phone restart silently cancelled every prayer notification until the
 * user next opened the app. Phones reboot for system updates on their own, which
 * makes this an unattributable "the adhan just stopped" rather than something a
 * user would think to report.
 *
 * It also handles the clock moving underneath a schedule that was computed
 * against the old one:
 *
 *  - `TIMEZONE_CHANGED` — flying somewhere else. Prayer times are absolute
 *    instants, but they were derived from the *old* location, so they are simply
 *    wrong on arrival until something re-plans.
 *  - `TIME_SET` — the clock corrected manually or by the network.
 *
 * ## Why it re-plans rather than shifting the existing alarms
 * Prayer times are not a fixed offset from the clock: a new timezone usually
 * means a new location, and Fajr in Cairo is not Fajr in Riyadh plus an hour.
 * Recomputing from the cached location is the only correct answer.
 *
 * The cached location is used deliberately — `resolve()` would mean a location
 * request from a broadcast receiver, which cannot prompt and would fail anyway.
 * With no cached location there is nothing to compute and the receiver does
 * nothing, which is the same state the app was in before the reboot.
 */
class ScheduleRestoreReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_TIME_CHANGED,
            -> Unit
            // Registered actions only. A receiver that acts on anything it is
            // handed is a receiver that fires on the next action someone adds.
            else -> return
        }

        val entryPoint = EntryPointAccessors.fromApplication(
            context.applicationContext, ScheduleRestoreEntryPoint::class.java,
        )

        restorePrayerAlarms(entryPoint)
        restoreWirdAlarms(entryPoint)
    }

    private fun restorePrayerAlarms(entryPoint: ScheduleRestoreEntryPoint) {
        val location = entryPoint.locationProvider().cached() ?: return
        val today = LocalDate.now()
        val timeline = runCatching {
            PrayerEngine().timeline(
                location.latitude, location.longitude,
                today.year, today.monthValue, today.dayOfMonth,
                days = NOTIFICATION_HORIZON_DAYS,
                settings = PrayerSettings(),
            )
        }.getOrNull() ?: return

        val scheduler = entryPoint.prayerNotificationScheduler()
        scheduler.ensureChannel()
        scheduler.reschedule(
            timeline,
            entryPoint.notificationPreferenceStore().load(),
            Clock.System.now(),
        )
    }

    /**
     * The wird reminders are lost to a reboot for the same reason, and restoring
     * only the prayer schedule would leave a user wondering why one kind of
     * reminder came back and the other did not.
     */
    private fun restoreWirdAlarms(entryPoint: ScheduleRestoreEntryPoint) {
        runCatching {
            val scheduler = entryPoint.wirdReminderScheduler()
            scheduler.ensureChannel()
            scheduler.reschedule(
                preferences = entryPoint.wirdReminderPreferenceStore().load(),
                // The real list, not an empty one. `reschedule` cancels before
                // it arms, so passing nothing would have *deleted* every wird
                // reminder in the name of restoring them.
                wirds = entryPoint.wirdStore().loadWirds(),
            )
        }
    }

    private companion object {
        /** Matches the app's own horizon; see PrayerViewModel. */
        const val NOTIFICATION_HORIZON_DAYS = 30
    }
}
