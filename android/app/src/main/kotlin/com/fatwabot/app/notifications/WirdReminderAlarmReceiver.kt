package com.fatwabot.app.notifications

import android.Manifest
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.core.content.getSystemService
import com.fatwabot.app.R
import com.fatwabot.core.common.DeepLink
import com.fatwabot.feature.awrad.PlannedWirdReminder
import dagger.hilt.EntryPoint
import dagger.hilt.InstallIn
import dagger.hilt.android.EntryPointAccessors
import dagger.hilt.components.SingletonComponent

/** See the note on `WirdResponderEntryPoint`: Kotlin BroadcastReceivers reach
 * their dependencies through an entry point rather than field injection. */
@EntryPoint
@InstallIn(SingletonComponent::class)
private interface WirdSchedulerEntryPoint {
    fun wirdReminderScheduler(): WirdReminderScheduler
}

/**
 * Posts the "did you complete [wird]؟" notification when its alarm fires, with
 * the two answer buttons attached. Registered in the app manifest. Mirror of the
 * iOS `WirdReminderScheduler` + delegate pair.
 */
class WirdReminderAlarmReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getStringExtra(WirdReminderScheduler.EXTRA_ID) ?: return
        val wirdId = intent.getStringExtra(WirdReminderScheduler.EXTRA_WIRD_ID) ?: return
        val wirdName = intent.getStringExtra(WirdReminderScheduler.EXTRA_WIRD_NAME).orEmpty()
        val hour = intent.getIntExtra(WirdReminderScheduler.EXTRA_HOUR, 20)
        val minute = intent.getIntExtra(WirdReminderScheduler.EXTRA_MINUTE, 0)

        // Re-arm BEFORE the permission check: a user who has notifications off
        // today may grant them tomorrow, and a chain that stops the first time it
        // can't post never restarts.
        EntryPointAccessors
            .fromApplication(context.applicationContext, WirdSchedulerEntryPoint::class.java)
            .wirdReminderScheduler()
            .arm(PlannedWirdReminder(id, wirdId, wirdName, hour, minute))

        if (ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return
        }

        val notificationId = id.hashCode()
        val builder = NotificationCompat.Builder(context, WirdReminderScheduler.CHANNEL_ID)
            .setSmallIcon(com.fatwabot.core.designsystem.R.drawable.ic_notification)
            .setContentTitle(context.getString(R.string.notif_wird_title, wirdName))
            .setContentText(context.getString(R.string.notif_wird_body))
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            // The point of the whole feature: answer without opening the app.
            .addAction(
                0,
                context.getString(R.string.notif_wird_action_yes),
                actionIntent(context, WirdReminderActionReceiver.ACTION_DONE, wirdId, notificationId),
            )
            .addAction(
                0,
                context.getString(R.string.notif_wird_action_later),
                actionIntent(context, WirdReminderActionReceiver.ACTION_LATER, wirdId, notificationId),
            )

        // Tapping the body (rather than a button) opens the Awrad screen, through
        // the same fatwabot:// route MainActivity already handles.
        contentIntent(context, id)?.let(builder::setContentIntent)

        context.getSystemService<NotificationManager>()?.notify(notificationId, builder.build())
    }

    private fun actionIntent(
        context: Context,
        action: String,
        wirdId: String,
        notificationId: Int,
    ): PendingIntent {
        val intent = Intent(context, WirdReminderActionReceiver::class.java).apply {
            this.action = action
            putExtra(WirdReminderActionReceiver.EXTRA_WIRD_ID, wirdId)
            putExtra(WirdReminderActionReceiver.EXTRA_NOTIFICATION_ID, notificationId)
        }
        return PendingIntent.getBroadcast(
            context,
            // The action is part of the request code: without it the two buttons
            // would collide on one PendingIntent and "لاحقاً" would mark it done.
            (action + wirdId).hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun contentIntent(context: Context, id: String): PendingIntent? {
        val intent = Intent(Intent.ACTION_VIEW, DeepLink.AWRAD.uri).apply {
            setPackage(context.packageName)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            // Otherwise MainActivity can't tell this from a widget tap and would
            // report it as one, inflating the metric that justifies the widgets.
            putExtra(ContentReminderAlarmReceiver.EXTRA_FROM_NOTIFICATION, true)
        }
        return PendingIntent.getActivity(
            context, id.hashCode(), intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
