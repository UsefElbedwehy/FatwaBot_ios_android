package com.fatwabot.app.analytics

import com.fatwabot.core.common.AnalyticsTracking
import com.google.firebase.analytics.FirebaseAnalytics
import com.google.firebase.analytics.ktx.logEvent
import com.google.firebase.crashlytics.FirebaseCrashlytics

/**
 * Firebase-backed [AnalyticsTracking]. Lives in `:app` so the SDK never leaks
 * into feature modules (ADR-0010).
 *
 * Every call is a no-op when the user has opted out — checked here rather than
 * only at the SDK level, so an opt-out also stops us buffering anything in
 * memory before the SDK's own flag is consulted.
 */
class FirebaseAnalyticsTracker(
    private val analytics: FirebaseAnalytics,
    private val crashlytics: FirebaseCrashlytics,
    private val preferences: AnalyticsPreferences,
) : AnalyticsTracking {

    /** Current choice, for the Settings toggle to render. */
    val isCollectionEnabled: Boolean get() = preferences.isEnabled

    /** Apply the persisted choice to both SDKs. Call once on app start. */
    fun applyPersistedChoice() = setCollectionEnabled(preferences.isEnabled)

    override fun screenView(screen: String) {
        if (!preferences.isEnabled) return
        analytics.logEvent(FirebaseAnalytics.Event.SCREEN_VIEW) {
            param(FirebaseAnalytics.Param.SCREEN_NAME, screen)
        }
    }

    override fun event(name: String, params: Map<String, String>) {
        if (!preferences.isEnabled) return
        analytics.logEvent(name) {
            params.forEach { (key, value) -> param(key, value) }
        }
    }

    override fun nonFatal(error: Throwable) {
        if (!preferences.isEnabled) return
        crashlytics.recordException(error)
    }

    override fun setCollectionEnabled(enabled: Boolean) {
        preferences.isEnabled = enabled
        analytics.setAnalyticsCollectionEnabled(enabled)
        crashlytics.isCrashlyticsCollectionEnabled = enabled
    }
}
