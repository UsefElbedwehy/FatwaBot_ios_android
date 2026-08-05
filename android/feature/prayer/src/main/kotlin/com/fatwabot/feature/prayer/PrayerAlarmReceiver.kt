package com.fatwabot.feature.prayer

import android.Manifest
import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.app.PendingIntent
import android.content.pm.PackageManager
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.core.content.getSystemService
import com.fatwabot.core.common.DeepLink

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
            .setSmallIcon(com.fatwabot.core.designsystem.R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            // Without a content intent an Android notification is INERT on tap —
            // it doesn't even open the app. Every prayer kind (adhan, pre-adhan,
            // iqama, last-third) lands on the Prayer screen.
            .setContentIntent(prayerTapIntent(context, id))
            .build()

        context.getSystemService<NotificationManager>()?.notify(id.hashCode(), notification)
    }

    private fun prayerTapIntent(context: Context, id: String): PendingIntent {
        val intent = Intent(Intent.ACTION_VIEW, DeepLink.PRAYER.uri).apply {
            setPackage(context.packageName)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            // Same extra the content reminders set, so MainActivity attributes
            // this as a notification open rather than inflating the widget metric.
            putExtra(DeepLink.EXTRA_FROM_NOTIFICATION, true)
        }
        return PendingIntent.getActivity(
            context, id.hashCode(), intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

}
