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

/**
 * Posts the azkar/hadith reminder when its alarm fires. Registered in the app
 * manifest. Mirror of the iOS `NotificationTapDelegate` half of the flow.
 */
class ContentReminderAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return
        }
        val id = intent.getStringExtra(ContentReminderScheduler.EXTRA_ID) ?: return
        val title = intent.getStringExtra(ContentReminderScheduler.EXTRA_TITLE).orEmpty()
        val body = intent.getStringExtra(ContentReminderScheduler.EXTRA_BODY).orEmpty()
        val host = intent.getStringExtra(ContentReminderScheduler.EXTRA_DEEP_LINK)
        val contentId = intent.getStringExtra(ContentReminderScheduler.EXTRA_CONTENT_ID)
        val categorySlug = intent.getStringExtra(ContentReminderScheduler.EXTRA_CATEGORY_SLUG)

        val builder = NotificationCompat.Builder(context, ContentReminderScheduler.CHANNEL_ID)
            .setSmallIcon(com.fatwabot.core.designsystem.R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            // Scripture runs past one line; without this the user only ever sees
            // the truncated head of an already-truncated body.
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)

        // Tapping opens the matching screen, through the same fatwabot:// route
        // MainActivity already handles for widget taps.
        contentIntent(context, host, id, contentId, categorySlug)?.let(builder::setContentIntent)

        context.getSystemService<NotificationManager>()?.notify(id.hashCode(), builder.build())
    }

    private fun contentIntent(
        context: Context,
        host: String?,
        id: String,
        contentId: String?,
        categorySlug: String?,
    ): PendingIntent? {
        val link = DeepLink.entries.firstOrNull { it.host == host } ?: return null
        val intent = Intent(Intent.ACTION_VIEW, link.uri).apply {
            setPackage(context.packageName)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            // Otherwise MainActivity can't tell this from a widget tap and would
            // report it as one, inflating the metric that justifies the widgets.
            putExtra(EXTRA_FROM_NOTIFICATION, true)
            // Which specific item to land on — read back by MainActivity to
            // build a ContentFocus. Absent for every other notification kind.
            putExtra(ContentReminderScheduler.EXTRA_CONTENT_ID, contentId)
            putExtra(ContentReminderScheduler.EXTRA_CATEGORY_SLUG, categorySlug)
        }
        return PendingIntent.getActivity(
            context, id.hashCode(), intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    companion object {
        /**
         * Set on the tap intent so MainActivity can attribute the open correctly.
         * Aliases the shared constant so every receiver and the activity resolve
         * to ONE literal — two copies is how the value drifts and taps start
         * being mis-attributed as widget opens.
         */
        const val EXTRA_FROM_NOTIFICATION = DeepLink.EXTRA_FROM_NOTIFICATION
    }
}
