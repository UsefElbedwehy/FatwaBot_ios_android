package com.fatwabot.app.analytics

import com.fatwabot.core.common.AnalyticsTracking

/**
 * Fans one [AnalyticsTracking] call out to several sinks. Android dual-sends:
 * Firebase (free aggregate/retention dashboards, and Crashlytics uses it for
 * breadcrumbs) plus our own ingest (`BackendAnalyticsRecorder`), so the
 * first-party dataset is cross-platform and comparable with iOS in one
 * dashboard.
 *
 * Every child is invoked independently and failures are swallowed per child: a
 * sink that is disabled, unconfigured, or throwing must not stop the others, and
 * analytics must never surface an error or break the call site.
 */
class CompositeAnalyticsTracking(
    private val sinks: List<AnalyticsTracking>,
) : AnalyticsTracking {

    override fun screenView(screen: String) = each { it.screenView(screen) }

    override fun event(name: String, params: Map<String, String>) = each { it.event(name, params) }

    override fun nonFatal(error: Throwable) = each { it.nonFatal(error) }

    override fun setCollectionEnabled(enabled: Boolean) = each { it.setCollectionEnabled(enabled) }

    private inline fun each(action: (AnalyticsTracking) -> Unit) {
        sinks.forEach { runCatching { action(it) } }
    }
}
