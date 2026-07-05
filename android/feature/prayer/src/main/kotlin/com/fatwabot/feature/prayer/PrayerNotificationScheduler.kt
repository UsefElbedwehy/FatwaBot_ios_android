package com.fatwabot.feature.prayer

import android.annotation.SuppressLint
import android.app.AlarmManager
import android.app.NotificationChannel
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
        val plan = NotificationPlanner.plan(timeline, preferences, now)
        plan.forEach { item ->
            val pending = pendingIntent(item)
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                item.fireEpochSeconds * 1000,
                pending,
            )
        }
        // Persist ids so a later cancelAll() can target them across process restarts.
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putStringSet(KEY_IDS, plan.map { it.id }.toSet())
            .apply()
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
        const val CHANNEL_ID = "prayer_reminders"
        const val EXTRA_ID = "id"
        const val EXTRA_TITLE = "title"
        const val EXTRA_BODY = "body"
        private const val PREFS = "prayer_notifications"
        private const val KEY_IDS = "scheduled_ids"
    }
}
