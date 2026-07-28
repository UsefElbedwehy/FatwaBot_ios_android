package com.fatwabot.app

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalConfiguration
import com.fatwabot.app.analytics.FirebaseAnalyticsTracker
import com.fatwabot.core.common.AnalyticsEvents
import com.fatwabot.core.common.AnalyticsTracking
import com.fatwabot.core.common.DeepLink
import com.fatwabot.core.network.BackendAnalyticsRecorder
import androidx.lifecycle.lifecycleScope
import com.fatwabot.app.navigation.AppRoot
import com.fatwabot.app.notifications.ContentReminderAlarmReceiver
import com.fatwabot.app.push.PushTokenRegistrar
import com.fatwabot.app.theme.ThemeModeController
import com.fatwabot.core.designsystem.FatwaBotTheme
import com.google.firebase.messaging.FirebaseMessaging
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject
import kotlinx.coroutines.launch

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    @Inject lateinit var pushRegistrar: PushTokenRegistrar

    /** The dual-send composite (Firebase + our own ingest) — what events go through. */
    @Inject lateinit var analytics: AnalyticsTracking

    /** Concrete, only for mirroring the persisted opt-out into the SDKs. */
    @Inject lateinit var firebaseAnalytics: FirebaseAnalyticsTracker

    /** Concrete, only for the flush lifecycle below. */
    @Inject lateinit var backendAnalytics: BackendAnalyticsRecorder

    override fun onCreate(savedInstanceState: Bundle?) {
        // Swap the splash window background (Theme.FatwaBot.Splash) for the real
        // app theme once we're drawing Compose content.
        setTheme(R.style.Theme_FatwaBot)
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        ThemeModeController.init(this)
        // Before anything is reported: mirror the user's opt-out into both SDKs.
        firebaseAnalytics.applyPersistedChoice()
        // Ship whatever the last session left queued (mirrors iOS flushing in
        // `.task`). Safe to do unconditionally: flush is a no-op when the queue is
        // empty or the user has opted out.
        flushAnalytics()
        registerPushToken()
        DeepLink.from(intent?.data)?.let { reportOpen(it, intent) }
        setContent {
            // Override uiMode per the user's appearance choice so every
            // isSystemInDarkTheme() read across the app reflects it.
            val mode = ThemeModeController.mode
            val base = LocalConfiguration.current
            val config = remember(mode, base) { ThemeModeController.applied(base) }
            // Held in state (not read straight off `intent`) so onNewIntent can
            // re-route a warm app, and so consuming it survives recomposition.
            var pendingLink by remember { mutableStateOf(DeepLink.from(intent?.data)) }
            deepLinkSink = { pendingLink = it }
            CompositionLocalProvider(LocalConfiguration provides config) {
                FatwaBotTheme {
                    AppRoot(deepLink = pendingLink, onDeepLinkHandled = { pendingLink = null })
                }
            }
        }
    }

    /** Set by the composition so a warm-start intent can reach it. */
    private var deepLinkSink: ((DeepLink?) -> Unit)? = null

    /**
     * The activity is `singleTop`-ish in practice: tapping a widget while the
     * app is already running delivers here rather than through onCreate, so
     * without this a second widget tap would do nothing.
     */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        DeepLink.from(intent.data)?.let { link ->
            deepLinkSink?.invoke(link)
            reportOpen(link, intent)
        }
    }

    /**
     * The app is going out of view — get the batch out now rather than waiting for
     * `batchThreshold` (mirrors iOS flushing on `scenePhase == .background`).
     *
     * This is the activity's own `onStop` rather than a `ProcessLifecycleOwner`
     * observer: the app is single-activity, so onStop already *is* "the app went
     * to background", and it needs no new `lifecycle-process` dependency. The
     * price is a redundant flush on configuration change, which costs nothing —
     * an empty queue short-circuits, and the ingest is idempotent per
     * `client_event_id`.
     */
    override fun onStop() {
        super.onStop()
        flushAnalytics()
    }

    /** Fire-and-forget: a failed or cancelled flush leaves events queued for the
     * next attempt, and analytics must never block or surface an error. */
    private fun flushAnalytics() {
        lifecycleScope.launch { backendAnalytics.flush() }
    }

    /**
     * Which routes actually get tapped. Widget and notification opens are counted
     * separately — the widget number is the one signal that tells us whether the
     * widgets are earning their place on the home screen, so daily-reminder taps
     * must not be folded into it.
     */
    private fun reportOpen(link: DeepLink, intent: Intent?) {
        val fromNotification = intent
            ?.getBooleanExtra(ContentReminderAlarmReceiver.EXTRA_FROM_NOTIFICATION, false) == true
        analytics.event(
            if (fromNotification) {
                AnalyticsEvents.NOTIFICATION_OPENED_APP
            } else {
                AnalyticsEvents.WIDGET_OPENED_APP
            },
            mapOf(AnalyticsEvents.PARAM_ROUTE to link.host),
        )
    }

    /** Fetch the current FCM token on launch and (re)register it with the backend. */
    private fun registerPushToken() {
        FirebaseMessaging.getInstance().token.addOnSuccessListener { token ->
            lifecycleScope.launch { pushRegistrar.register(token) }
        }
    }
}
