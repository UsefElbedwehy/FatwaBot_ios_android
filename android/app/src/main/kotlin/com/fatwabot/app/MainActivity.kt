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
import com.fatwabot.core.common.DeepLink
import androidx.lifecycle.lifecycleScope
import com.fatwabot.app.navigation.AppRoot
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

    override fun onCreate(savedInstanceState: Bundle?) {
        // Swap the splash window background (Theme.FatwaBot.Splash) for the real
        // app theme once we're drawing Compose content.
        setTheme(R.style.Theme_FatwaBot)
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        ThemeModeController.init(this)
        registerPushToken()
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
        DeepLink.from(intent.data)?.let { link -> deepLinkSink?.invoke(link) }
    }

    /** Fetch the current FCM token on launch and (re)register it with the backend. */
    private fun registerPushToken() {
        FirebaseMessaging.getInstance().token.addOnSuccessListener { token ->
            lifecycleScope.launch { pushRegistrar.register(token) }
        }
    }
}
