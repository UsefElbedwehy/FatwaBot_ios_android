package com.fatwabot.feature.gamification

import com.fatwabot.core.common.GamificationWidgetSnapshotStore
import com.fatwabot.core.network.AuthenticatedApiClientProtocol
import java.io.File
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

private class FakeProfileApiClient(
    private val onGet: (String, Map<String, String>) -> String,
) : AuthenticatedApiClientProtocol {
    override suspend fun getRaw(path: String, query: Map<String, String>): String = onGet(path, query)
    override suspend fun postRaw(path: String, jsonBody: String) = ""
    override suspend fun postEmptyRaw(path: String) = ""
    override suspend fun patchRaw(path: String, jsonBody: String) = ""
    override suspend fun deleteRaw(path: String) = ""
}

class GamificationViewModelTest {

    @Test
    fun loadPopulatesProfileFromServer() = runTest {
        val client = FakeProfileApiClient { path, query ->
            assertEquals("v1/gamification/profile", path)
            assertTrue(query.containsKey("timezone"))
            """{"streaks":[{"key":"fajr","name":"Fajr Streak","current_length":3,"longest_length":10,"grace_remaining":1}],"missions":[],"badges":[]}"""
        }
        val viewModel = GamificationViewModel(client, recorder = null)

        viewModel.load()

        val state = viewModel.state.value
        assertEquals(1, state.profile.streaks.size)
        assertEquals("Fajr Streak", state.profile.streaks.first().name)
        assertEquals(false, state.isLoading)
    }

    @Test
    fun loadSurfacesErrorOnFailure() = runTest {
        val client = FakeProfileApiClient { _, _ -> throw RuntimeException("boom") }
        val viewModel = GamificationViewModel(client, recorder = null)

        viewModel.load()

        assertNotNull(viewModel.state.value.error)
        assertEquals(GamificationProfile.EMPTY, viewModel.state.value.profile)
    }

    @Test
    fun loadWritesWidgetSnapshotWithLongestStreakAndFirstIncompleteDailyMission() = runTest {
        val file = File.createTempFile("gamification-widget-snapshot", ".json").apply { deleteOnExit() }
        val widgetStore = GamificationWidgetSnapshotStore(file)
        val client = FakeProfileApiClient { _, _ ->
            """
            {"streaks":[
              {"key":"azkar","name":"Azkar","current_length":3,"longest_length":10,"grace_remaining":0},
              {"key":"fajr","name":"Fajr","current_length":7,"longest_length":7,"grace_remaining":1}
            ],"missions":[
              {"key":"m1","name":"Done Today","progress":3,"target":3,"window":"daily"},
              {"key":"m2","name":"In Progress","progress":1,"target":3,"window":"daily"},
              {"key":"m3","name":"Weekly Thing","progress":1,"target":3,"window":"weekly"}
            ],"badges":[]}
            """.trimIndent()
        }
        val viewModel = GamificationViewModel(client, recorder = null, widgetStore = widgetStore)

        viewModel.load()

        val snapshot = widgetStore.read()
        assertEquals("Fajr", snapshot?.topStreak?.name)
        assertEquals("In Progress", snapshot?.dailyChallenge?.name)
    }

    @Test
    fun loadDoesNotWriteWidgetSnapshotWhenRequestFails() = runTest {
        val file = File.createTempFile("gamification-widget-snapshot", ".json").apply { deleteOnExit() }
        val widgetStore = GamificationWidgetSnapshotStore(file)
        val client = FakeProfileApiClient { _, _ -> throw RuntimeException("boom") }
        val viewModel = GamificationViewModel(client, recorder = null, widgetStore = widgetStore)

        viewModel.load()

        assertNull(widgetStore.read())
    }
}
