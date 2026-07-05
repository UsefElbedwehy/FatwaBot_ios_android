package com.fatwabot.feature.prayer

import android.Manifest
import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.core.content.getSystemService

/** Posts the prayer notification when an alarm fires. Registered in the app manifest. */
class PrayerAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return
        }
        val id = intent.getStringExtra(PrayerNotificationScheduler.EXTRA_ID) ?: return
        val title = intent.getStringExtra(PrayerNotificationScheduler.EXTRA_TITLE).orEmpty()
        val body = intent.getStringExtra(PrayerNotificationScheduler.EXTRA_BODY).orEmpty()

        val notification = NotificationCompat.Builder(context, PrayerNotificationScheduler.CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build()

        context.getSystemService<NotificationManager>()?.notify(id.hashCode(), notification)
    }
}
