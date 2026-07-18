package com.fatwabot.feature.leaderboard

import com.fatwabot.core.common.HapticsProviding
import com.fatwabot.core.common.NoopHaptics
import com.fatwabot.core.network.AuthenticatedApiClientProtocol
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

private class FakeApiClient(
    private val onGet: (String) -> String = { """{"boards":[]}""" },
    private val onPostRaw: (String, String) -> String = { _, _ -> """{"handle":"anon_1","publish_name":false,"city":null}""" },
    private val onPostEmptyRaw: (String) -> String = { """{"left":true}""" },
) : AuthenticatedApiClientProtocol {
    var getCallCount = 0
        private set

    override suspend fun getRaw(path: String, query: Map<String, String>): String {
        getCallCount++
        return onGet(path)
    }
    override suspend fun postRaw(path: String, jsonBody: String): String = onPostRaw(path, jsonBody)
    override suspend fun postEmptyRaw(path: String): String = onPostEmptyRaw(path)
    override suspend fun patchRaw(path: String, jsonBody: String) = ""
    override suspend fun deleteRaw(path: String) = ""
}

class LeaderboardViewModelTest {
    private val boardJson = """
        {"boards":[{"key":"weekly_fajr","name":"Weekly Fajr","scope":"global","period":"weekly",
        "joined":true,"my_rank":1,"entries":[{"rank":1,"score":42.0,"display_name":"anon_123"}]}]}
    """.trimIndent()

    @Test
    fun `load populates boards from server`() = runTest {
        val client = FakeApiClient(onGet = { path -> assertEquals("v1/leaderboards", path); boardJson })
        val viewModel = LeaderboardViewModel(client, NoopHaptics())

        viewModel.load()

        val state = viewModel.state.value
        assertEquals(1, state.boards.size)
        assertTrue(state.boards[0].joined)
        assertEquals(1, state.boards[0].myRank)
        assertEquals(null, state.error)
    }

    @Test
    fun `load surfaces error on failure`() = runTest {
        val client = FakeApiClient(onGet = { throw RuntimeException("unauthorized") })
        val viewModel = LeaderboardViewModel(client, NoopHaptics())

        viewModel.load()

        assertNotNull(viewModel.state.value.error)
        assertTrue(viewModel.state.value.boards.isEmpty())
    }

    @Test
    fun `join posts request then reloads`() = runTest {
        var joinPath: String? = null
        val client = FakeApiClient(
            onGet = { boardJson },
            onPostRaw = { path, _ -> joinPath = path; """{"handle":"anon_1","publish_name":false,"city":null}""" },
        )
        val viewModel = LeaderboardViewModel(client, NoopHaptics())

        viewModel.join("weekly_fajr", publishName = false, city = null)

        assertEquals("v1/leaderboards/weekly_fajr/join", joinPath)
        assertEquals(1, client.getCallCount)
        assertTrue(viewModel.state.value.boards[0].joined)
    }

    @Test
    fun `join fires a target-reached haptic on success but not on failure`() = runTest {
        val haptics = object : HapticsProviding {
            var tickCount = 0
            var targetReachedCount = 0
            override fun tick() { tickCount += 1 }
            override fun targetReached() { targetReachedCount += 1 }
        }
        val client = FakeApiClient(onGet = { boardJson })
        val viewModel = LeaderboardViewModel(client, haptics)

        viewModel.join("weekly_fajr", publishName = false, city = null)
        assertEquals(1, haptics.targetReachedCount)

        val failingClient = FakeApiClient(onGet = { boardJson }, onPostRaw = { _, _ -> throw RuntimeException("offline") })
        val failingViewModel = LeaderboardViewModel(failingClient, haptics)
        failingViewModel.join("weekly_fajr", publishName = false, city = null)
        assertEquals("must not fire on a failed join", 1, haptics.targetReachedCount)
    }

    @Test
    fun `leave posts to leave endpoint then reloads`() = runTest {
        var leavePath: String? = null
        val notJoinedJson = """{"boards":[{"key":"weekly_fajr","name":"Weekly Fajr","scope":"global","period":"weekly","joined":false}]}"""
        val client = FakeApiClient(
            onGet = { notJoinedJson },
            onPostEmptyRaw = { path -> leavePath = path; """{"left":true}""" },
        )
        val viewModel = LeaderboardViewModel(client, NoopHaptics())

        viewModel.leave("weekly_fajr")

        assertEquals("v1/leaderboards/weekly_fajr/leave", leavePath)
        assertFalse(viewModel.state.value.boards[0].joined)
    }
}
