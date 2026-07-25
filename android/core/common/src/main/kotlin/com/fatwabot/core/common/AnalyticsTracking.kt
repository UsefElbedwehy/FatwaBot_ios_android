package com.fatwabot.core.common

/**
 * Product-analytics boundary. Hoisted here (mirrors [ActivityEventRecording] and
 * HapticsProviding) so feature modules never depend on Firebase directly — the
 * SDK stays an `:app`-only implementation detail and features stay unit-testable
 * with [NoopAnalyticsTracking].
 *
 * Android **dual-sends**: the bound implementation is a composite over
 * `FirebaseAnalyticsTracker` (free aggregate/retention dashboards, and
 * Crashlytics uses it for breadcrumbs) and
 * `com.fatwabot.core.network.BackendAnalyticsRecorder`, which posts to our OWN
 * ingest so the first-party dataset covers both platforms. iOS single-sends to
 * that same ingest (no Firebase SDK there by design), so the event and param
 * names below must stay byte-identical to iOS `AnalyticsEvents` — a mismatch
 * silently splits a metric across two names in one dashboard.
 *
 * ## What must never be logged
 *
 * This is a worship app used by anonymous users, and analytics goes to a third
 * party. Treat the following as forbidden payloads, not merely discouraged:
 *
 *  - **Search queries.** "Is X permissible" is among the most sensitive things a
 *    user types. Log that a search happened, never what it said.
 *  - **Location.** Not coordinates, not city. Prayer times are computed on-device
 *    precisely so location never leaves it.
 *  - **Identity.** No display name, email, user id, or push token.
 *  - **Content bodies.** Du'a/hadith text or personal wird notes. An id or a
 *    category key is fine; free text is not.
 *
 * Counts, screen names, and stable category keys are the intended payloads.
 */
interface AnalyticsTracking {
    /** A screen became visible. [screen] must be a stable, non-PII key. */
    fun screenView(screen: String)

    /**
     * A product event. [params] values must be stable keys or numbers — never
     * user-authored text (see the class doc).
     */
    fun event(name: String, params: Map<String, String> = emptyMap())

    /**
     * Record a handled error for triage without crashing. Pass an exception, not
     * a formatted user-facing string, so it groups correctly.
     */
    fun nonFatal(error: Throwable)

    /** Mirrors the user's privacy choice into the underlying SDKs. */
    fun setCollectionEnabled(enabled: Boolean)
}

/** Default binding for tests and any build without a reporting backend. */
class NoopAnalyticsTracking : AnalyticsTracking {
    override fun screenView(screen: String) {}
    override fun event(name: String, params: Map<String, String>) {}
    override fun nonFatal(error: Throwable) {}
    override fun setCollectionEnabled(enabled: Boolean) {}
}

/**
 * Canonical event + screen names, so the same concept isn't logged as
 * `dua_opened` on one screen and `open_dua` on another — which silently splits
 * a metric across two names in the dashboard.
 */
object AnalyticsEvents {
    // Screens
    const val SCREEN_HOME = "home"
    const val SCREEN_WORSHIP = "worship"
    const val SCREEN_SETTINGS = "settings"
    const val SCREEN_PRAYER = "prayer_times"
    const val SCREEN_QIBLA = "qibla"
    const val SCREEN_TASBEEH = "tasbeeh"
    const val SCREEN_AZKAR = "azkar"
    const val SCREEN_DUA = "dua"
    const val SCREEN_AWRAD = "awrad"
    const val SCREEN_HADITH = "hadith"
    const val SCREEN_JOURNEY = "journey"

    // Events
    const val SCREEN_VIEW = "screen_view"
    const val WIDGET_OPENED_APP = "widget_opened_app"
    const val SEARCH_SUBMITTED = "search_submitted"
    const val NON_FATAL_ERROR = "non_fatal_error"
    const val TASBEEH_SESSION_COMPLETED = "tasbeeh_session_completed"
    const val AZKAR_CATEGORY_COMPLETED = "azkar_category_completed"
    const val NOTIFICATION_PREFS_CHANGED = "notification_prefs_changed"

    // Param keys
    const val PARAM_SCREEN = "screen"
    const val PARAM_ROUTE = "route"
    const val PARAM_CATEGORY = "category"
    const val PARAM_COUNT = "count"
    const val PARAM_ERROR_TYPE = "error_type"
}
