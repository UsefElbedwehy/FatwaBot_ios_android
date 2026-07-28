package com.fatwabot.app.notifications

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.content.getSystemService
import com.fatwabot.feature.awrad.WirdCompletionResponder
import dagger.hilt.EntryPoint
import dagger.hilt.InstallIn
import dagger.hilt.android.EntryPointAccessors
import dagger.hilt.components.SingletonComponent
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/** Hilt can't field-inject a BroadcastReceiver from Kotlin (`super.onReceive` is
 * abstract, so the generated base class is unreachable), so the dependency is
 * pulled through an entry point — the same pattern `AppRoot` already uses. */
@EntryPoint
@InstallIn(SingletonComponent::class)
private interface WirdResponderEntryPoint {
    fun wirdCompletionResponder(): WirdCompletionResponder
}

/**
 * Handles the two answer buttons on a wird reminder. Registered in the app
 * manifest; mirror of the iOS `NotificationTapDelegate` action branch.
 *
 * The mutation runs here rather than in an Activity precisely so the user never
 * has to open the app: this receiver is woken with the app backgrounded or dead,
 * so there is no `AwradViewModel` to talk to and everything goes through
 * [WirdCompletionResponder] → `WirdStoring`. The view model re-reads the store on
 * its next `ON_RESUME`.
 */
class WirdReminderActionReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val wirdId = intent.getStringExtra(EXTRA_WIRD_ID) ?: return
        val notificationId = intent.getIntExtra(EXTRA_NOTIFICATION_ID, wirdId.hashCode())

        // Dismiss first and unconditionally: whichever button was pressed, the
        // question has been answered and leaving it in the shade invites the
        // double-tap the responder then has to absorb.
        context.getSystemService<NotificationManager>()?.cancel(notificationId)

        if (intent.action != ACTION_DONE) return

        // `goAsync` because the store read/write is disk I/O and `onReceive` runs
        // on the main thread with a hard time budget — without it a slow write
        // would be an ANR, and the process could be killed mid-write.
        val responder = EntryPointAccessors
            .fromApplication(context.applicationContext, WirdResponderEntryPoint::class.java)
            .wirdCompletionResponder()

        val result = goAsync()
        CoroutineScope(Dispatchers.IO).launch {
            try {
                responder.answerCompleted(wirdId)
            } finally {
                result.finish()
            }
        }
    }

    companion object {
        const val ACTION_DONE = "com.fatwabot.app.WIRD_REMINDER_DONE"
        const val ACTION_LATER = "com.fatwabot.app.WIRD_REMINDER_LATER"
        const val EXTRA_WIRD_ID = "wird_id"
        const val EXTRA_NOTIFICATION_ID = "notification_id"
    }
}
