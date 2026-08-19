package com.fatwabot.app.analytics

import com.fatwabot.core.common.AnalyticsTracking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

private class RecordingSink(private val throwOnEveryCall: Boolean = false) : AnalyticsTracking {
    val screens = mutableListOf<String>()
    val events = mutableListOf<Pair<String, Map<String, String>>>()
    val nonFatals = mutableListOf<Throwable>()
    var collectionEnabled: Boolean? = null

    override fun screenView(screen: String) {
        screens += screen
        fail()
    }

    override fun event(name: String, params: Map<String, String>) {
        events += name to params
        fail()
    }

    override fun nonFatal(error: Throwable) {
        nonFatals += error
        fail()
    }

    override fun setCollectionEnabled(enabled: Boolean) {
        collectionEnabled = enabled
        fail()
    }

    private fun fail() {
        if (throwOnEveryCall) throw IllegalStateException("sink is unhappy")
    }
}

class CompositeAnalyticsTrackingTest {

    @Test
    fun fansEverySignalOutToEverySink() {
        val a = RecordingSink()
        val b = RecordingSink()
        val composite = CompositeAnalyticsTracking(listOf(a, b))

        composite.screenView("dua")
        composite.event("widget_opened_app", mapOf("route" to "dua"))
        composite.nonFatal(RuntimeException("boom"))
        composite.setCollectionEnabled(false)

        listOf(a, b).forEach { sink ->
            assertEquals(listOf("dua"), sink.screens)
            assertEquals(listOf("widget_opened_app" to mapOf("route" to "dua")), sink.events)
            assertEquals(1, sink.nonFatals.size)
            assertEquals(false, sink.collectionEnabled)
        }
    }

    /** A sink that is disabled, unconfigured or throwing must not take the others
     * down with it — nor propagate to the call site. */
    @Test
    fun oneFailingSinkDoesNotStopTheOthers() {
        val broken = RecordingSink(throwOnEveryCall = true)
        val healthy = RecordingSink()
        val composite = CompositeAnalyticsTracking(listOf(broken, healthy))

        composite.screenView("home")
        composite.event("search_submitted")
        composite.nonFatal(RuntimeException("boom"))
        composite.setCollectionEnabled(true)

        assertEquals(listOf("home"), healthy.screens)
        assertEquals(listOf("search_submitted" to emptyMap<String, String>()), healthy.events)
        assertEquals(1, healthy.nonFatals.size)
        assertEquals(true, healthy.collectionEnabled)
    }

    @Test
    fun noSinksIsHarmless() {
        val composite = CompositeAnalyticsTracking(emptyList())

        composite.screenView("home")

        assertTrue(true)
    }
}
