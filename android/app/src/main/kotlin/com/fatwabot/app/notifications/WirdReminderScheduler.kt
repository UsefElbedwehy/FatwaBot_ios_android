package com.fatwabot.app.notifications

import android.annotation.SuppressLint
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.core.content.getSystemService
import com.fatwabot.feature.awrad.PlannedWirdReminder
import com.fatwabot.feature.awrad.Wird
import com.fatwabot.feature.awrad.WirdReminderPlanner
import com.fatwabot.feature.awrad.WirdReminderPreferences
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId

/**
 * Registers the pure [WirdReminderPlanner] output with AlarmManager — mirror of
 * the iOS `WirdReminderScheduler`.
 *
 * Lives in `:app` rather than `:feature:awrad` because it composes the feature's
 * data with a platform API and the shared notification budget, the composition
 * role ADR-0010 assigns to the app layer (same as [ContentReminderScheduler]).
 */
class WirdReminderScheduler(
    private val context: Context,
    private val stringProvider: (String) -> String,
) {
    private val alarmManager = context.getSystemService<AlarmManager>()!!

    fun ensureChannel() {
        val manager = context.getSystemService<NotificationManager>()!!
        // Its own channel, so a user can silence the wird nudge without also
        // silencing the adhan or the daily azkar — very different in urgency.
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                stringProvider("notif.channel.wird"),
                NotificationManager.IMPORTANCE_DEFAULT,
            ),
        )
    }

    @SuppressLint("ScheduleExactAlarm")
    fun reschedule(
        preferences: WirdReminderPreferences,
        wirds: List<Wird>,
        nowMillis: Long = System.currentTimeMillis(),
        zone: ZoneId = ZoneId.systemDefault(),
    ) {
        cancelAll()

        val plan = WirdReminderPlanner.plan(wirds = wirds, preferences = preferences)
        plan.forEach { arm(it, nowMillis, zone) }

        // Persist ids so a later cancelAll() can target them across process
        // restarts — an alarm we've forgotten the id of can never be cancelled.
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putStringSet(KEY_IDS, plan.map { it.id }.toSet())
            .apply()
    }

    /**
     * Arms the next occurrence of one reminder. Called both when (re)planning and
     * from [WirdReminderAlarmReceiver] after a firing: AlarmManager has no exact
     * *repeating* alarm, so "daily" is one-shot alarms that re-arm themselves.
     */
    @SuppressLint("ScheduleExactAlarm")
    fun arm(item: PlannedWirdReminder, nowMillis: Long = System.currentTimeMillis(), zone: ZoneId = ZoneId.systemDefault()) {
        alarmManager.setExactAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            nextFireMillis(item.hour, item.minute, nowMillis, zone),
            pendingIntent(item),
        )
    }

    private fun cancelAll() {
        val ids = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getStringSet(KEY_IDS, emptySet()).orEmpty()
        ids.forEach { id ->
            alarmManager.cancel(
                PendingIntent.getBroadcast(
                    context, id.hashCode(),
                    Intent(context, WirdReminderAlarmReceiver::class.java),
                    PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
                ) ?: return@forEach,
            )
        }
    }

    private fun pendingIntent(item: PlannedWirdReminder): PendingIntent {
        val intent = Intent(context, WirdReminderAlarmReceiver::class.java).apply {
            putExtra(EXTRA_ID, item.id)
            putExtra(EXTRA_WIRD_ID, item.wirdId)
            putExtra(EXTRA_WIRD_NAME, item.wirdName)
            putExtra(EXTRA_HOUR, item.hour)
            putExtra(EXTRA_MINUTE, item.minute)
        }
        return PendingIntent.getBroadcast(
            context, item.id.hashCode(), intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    companion object {
        const val CHANNEL_ID = "wird_reminders"
        const val EXTRA_ID = "id"
        const val EXTRA_WIRD_ID = "wird_id"
        const val EXTRA_WIRD_NAME = "wird_name"
        const val EXTRA_HOUR = "hour"
        const val EXTRA_MINUTE = "minute"
        private const val PREFS = "wird_reminders"
        private const val KEY_IDS = "scheduled_ids"

        /**
         * Today at HH:MM if that is still ahead, otherwise tomorrow. Computed
         * through the calendar rather than by adding 24h so a DST jump moves the
         * reminder with the wall clock instead of an hour off it.
         */
        fun nextFireMillis(hour: Int, minute: Int, nowMillis: Long, zone: ZoneId): Long {
            val now = java.time.Instant.ofEpochMilli(nowMillis).atZone(zone)
            val today = now.toLocalDate().atTime(LocalTime.of(hour, minute)).atZone(zone)
            val target = if (today.toInstant().toEpochMilli() > nowMillis) {
                today
            } else {
                LocalDate.from(now).plusDays(1).atTime(LocalTime.of(hour, minute)).atZone(zone)
            }
            return target.toInstant().toEpochMilli()
        }
    }
}
