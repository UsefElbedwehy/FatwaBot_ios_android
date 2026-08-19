package com.fatwabot.feature.prayer

import android.annotation.SuppressLint
import android.app.AlarmManager
import android.app.NotificationChannel
import android.net.Uri
import android.media.AudioAttributes
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.core.content.getSystemService
import com.fatwabot.core.prayer.NotificationPlanner
import com.fatwabot.core.prayer.PlannedNotification
import com.fatwabot.core.prayer.PrayerDayUi
import com.fatwabot.core.prayer.PrayerNotificationPreferences
import kotlinx.datetime.Instant

/**
 * Registers the pure NotificationPlanner output with AlarmManager. A BroadcastReceiver
 * (PrayerAlarmReceiver) fires at the scheduled time and posts the notification — this
 * survives process death, matching iOS's OS-scheduled UNCalendarNotificationTrigger.
 * Reschedule on the same triggers as iOS (foreground, settings, location, daily refresh).
 */
class PrayerNotificationScheduler(
    private val context: Context,
    private val stringProvider: (String) -> String,
) {
    private val alarmManager = context.getSystemService<AlarmManager>()!!

    fun ensureChannel() {
        val manager = context.getSystemService<NotificationManager>()!!
        val channel = NotificationChannel(
            CHANNEL_ID,
            stringProvider("notif.channel.prayer"),
            NotificationManager.IMPORTANCE_HIGH,
        )
        // The adhan is the call to prayer; it should not sound like every other
        // notification. USAGE_ALARM rather than NOTIFICATION so it plays at alarm
        // volume and is not muted by a "silence notifications" profile — a prayer
        // reminder that a Do-Not-Disturb rule swallows has failed at its one job.
        //
        // A channel's sound is fixed at creation: Android ignores changes to an
        // existing channel, so a build that shipped without this keeps the default
        // until the app is reinstalled or the channel id changes. That is why the
        // id carries a version suffix.
        channel.setSound(
            Uri.parse("android.resource://${context.packageName}/${R.raw.adhan}"),
            AudioAttributes.Builder()
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .setUsage(AudioAttributes.USAGE_ALARM)
                .build(),
        )
        manager.createNotificationChannel(channel)
    }

    @SuppressLint("ScheduleExactAlarm")
    fun reschedule(
        timeline: List<PrayerDayUi>,
        preferences: PrayerNotificationPreferences,
        now: Instant,
    ) {
        // Cancel the previous window before scheduling the new one (stable ids).
        cancelAll()
        // A larger budget than iOS on purpose. The 48 ceiling exists because
        // iOS allows only 64 *pending* notifications; AlarmManager has no such
        // cap, so mirroring the limit here imported an iOS constraint onto
        // Android for no reason and shortened the horizon that survives when the
        // user does not open the app. Still bounded — exact alarms are a
        // resource, and some OEM builds throttle apps that register thousands.
        val plan = NotificationPlanner.plan(timeline, preferences, now, budget = ANDROID_BUDGET)
        plan.forEach { item -> arm(item) }
        // Persist ids so a later cancelAll() can target them across process restarts.
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putStringSet(KEY_IDS, plan.map { it.id }.toSet())
            .apply()
    }

    /**
     * Arms one notification, choosing the alarm API by kind.
     *
     * ## Why the adhan uses setAlarmClock
     * `setExactAndAllowWhileIdle` is *allowed* in Doze but not unrestricted:
     * Android enforces a minimum interval (historically ~9 minutes) between
     * successive such alarms from the same app. Our own schedule violates that
     * spacing — the pre-adhan reminder fires ten minutes before the adhan, so
     * the adhan itself lands inside the throttle window and is deferred. That is
     * the reported "الأذان يتأخر ٥ دقائق": intermittent, only on some prayers,
     * and impossible to reproduce with the app open because Doze is not active.
     *
     * `setAlarmClock` is exempt from that throttle entirely. It is the API the
     * platform intends for user-visible alarms, and a call to prayer is exactly
     * that.
     *
     * ## Why only the adhan
     * `setAlarmClock` surfaces in the system's "next alarm" slot and puts an
     * alarm icon in the status bar. That is honest for the adhan and noise for
     * everything else — a pre-adhan nudge or an iqama reminder is not what a
     * user means by "my next alarm", and four of them a day would make the
     * indicator meaningless. The softer kinds keep the previous API, where a few
     * minutes of drift costs nothing.
     */
    @SuppressLint("ScheduleExactAlarm")
    private fun arm(item: PlannedNotification) {
        val pending = pendingIntent(item)
        val triggerAtMillis = item.fireEpochSeconds * 1000

        if (item.kind.usesAlarmClock) {
            alarmManager.setAlarmClock(
                AlarmManager.AlarmClockInfo(triggerAtMillis, showIntent()),
                pending,
            )
        } else {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerAtMillis,
                pending,
            )
        }
    }

    /**
     * Where the system sends a user who taps the alarm indicator. Opening the
     * app is the only sensible destination; a null here would leave the
     * indicator inert.
     */
    private fun showIntent(): PendingIntent? =
        context.packageManager.getLaunchIntentForPackage(context.packageName)?.let {
            PendingIntent.getActivity(
                context, 0, it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

    private fun cancelAll() {
        val ids = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getStringSet(KEY_IDS, emptySet()).orEmpty()
        ids.forEach { id ->
            alarmManager.cancel(
                PendingIntent.getBroadcast(
                    context, id.hashCode(),
                    Intent(context, PrayerAlarmReceiver::class.java),
                    PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
                ) ?: return@forEach,
            )
        }
    }

    private fun pendingIntent(item: PlannedNotification): PendingIntent {
        val intent = Intent(context, PrayerAlarmReceiver::class.java).apply {
            putExtra(EXTRA_ID, item.id)
            putExtra(EXTRA_TITLE, stringProvider(item.titleKey))
            putExtra(EXTRA_BODY, stringProvider(item.bodyKey))
        }
        return PendingIntent.getBroadcast(
            context, item.id.hashCode(), intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    companion object {
        /** See the budget comment in [schedule]. */
        private const val ANDROID_BUDGET = 160

        // Suffixed because a channel's sound is immutable once created: without a
        // new id, every existing install would keep the default tone forever.
        const val CHANNEL_ID = "prayer_reminders_v2"
        const val EXTRA_ID = "id"
        const val EXTRA_TITLE = "title"
        const val EXTRA_BODY = "body"
        private const val PREFS = "prayer_notifications"
        private const val KEY_IDS = "scheduled_ids"
    }
}
