package com.fatwabot.feature.prayer

import com.fatwabot.core.prayer.WidgetSnapshotStore
import java.io.File
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import kotlinx.datetime.Clock
import kotlinx.datetime.Instant
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test

/** Mirrors iOS PrayerViewModelTests' cold-start widget-write deferral test. */
@OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
class PrayerViewModelTest {
    private class StubLocation(
        private val cachedLocation: UserLocation?,
        private val resolveResult: LocationState,
    ) : LocationProviding {
        override fun cached(): UserLocation? = cachedLocation
        override suspend fun resolve(): LocationState = resolveResult
        override fun setManualCity(city: ManualCity, displayName: String) {}
    }

    private val riyadh = UserLocation(24.7136, 46.6753, "الرياض", "SA", isManual = false)
    private val fixedClock = object : Clock {
        override fun now() = Instant.fromEpochSeconds(1_774_000_000)
    }

    @Before
    fun setUp() {
        Dispatchers.setMain(StandardTestDispatcher())
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun `cached location on init skips widget write but start does not skip it`() = runTest {
        val tmpFile = File.createTempFile("prayer-widget-snapshot", ".json")
        tmpFile.delete()
        tmpFile.deleteOnExit()
        val widgetStore = WidgetSnapshotStore(tmpFile)

        var reloadCount = 0
        val viewModel = PrayerViewModel(
            locationProvider = StubLocation(cachedLocation = riyadh, resolveResult = LocationState.Resolved(riyadh)),
            clock = fixedClock,
            scheduler = null,
            notificationPreferenceStore = null,
            widgetStore = widgetStore,
            onWidgetSnapshotWritten = PrayerViewModel.WidgetRefresh { reloadCount++ },
        )

        assertEquals("cached-location path in init must not do the widget disk write + reload call", 0, reloadCount)
        assertNull("no widget snapshot file should exist yet", widgetStore.read())

        viewModel.start()
        testScheduler.advanceUntilIdle()

        assertEquals("start() resolving location must still write the widget snapshot", 1, reloadCount)
    }
}
