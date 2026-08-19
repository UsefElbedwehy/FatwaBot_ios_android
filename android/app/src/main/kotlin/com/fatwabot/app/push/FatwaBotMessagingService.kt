package com.fatwabot.app.push

import android.annotation.SuppressLint
import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.core.content.getSystemService
import com.fatwabot.app.R
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/**
 * Receives FCM messages and token refreshes (M4 push). Notification-type
 * campaign messages are shown by the system when backgrounded and posted here
 * when foregrounded. New tokens are registered with the backend so campaigns
 * can target this device.
 */
@AndroidEntryPoint
class FatwaBotMessagingService : FirebaseMessagingService() {
    @Inject lateinit var registrar: PushTokenRegistrar
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    override fun onNewToken(token: String) {
        scope.launch { registrar.register(token) }
    }

    // Lint can't see the POST_NOTIFICATIONS check through `canPost()`, so it
    // reports MissingPermission on the notify() call. The guard is real — this
    // is a false positive, not an unchecked post.
    @SuppressLint("MissingPermission")
    override fun onMessageReceived(message: RemoteMessage) {
        val notification = message.notification ?: return
        ensureChannel()
        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(com.fatwabot.core.designsystem.R.drawable.ic_notification)
            .setContentTitle(notification.title)
            .setContentText(notification.body)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
        if (canPost()) {
            NotificationManagerCompat.from(this).notify(message.messageId?.hashCode() ?: 0, builder.build())
        }
    }

    private fun canPost(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED

    private fun ensureChannel() {
        val manager = getSystemService<NotificationManager>() ?: return
        if (manager.getNotificationChannel(CHANNEL_ID) == null) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, getString(R.string.notification_channel_general), NotificationManager.IMPORTANCE_HIGH),
            )
        }
    }

    companion object {
        const val CHANNEL_ID = "general"
    }
}
