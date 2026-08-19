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
        val viewModel = LeaderboardViewModel(client, NoopHaptics(), UnknownRegionResolver())

        viewModel.load()

        val state = viewModel.state.value
        assertEquals(1, state.boards.size)
        assertTrue(state.boards[0].joined)
        assertEquals(1, state.boards[0].myRank)
        assertEquals(null, state.error)
    }

    @Test
    fun `load decodes the period bounds from the backend's millisecond format`() = runTest {
        // `Date.prototype.toISOString()` on the backend always emits milliseconds
        // ("2026-01-01T00:00:00.000Z"), unlike the plain-second examples in most
        // ISO 8601 docs — pin that `Instant`-based parsing actually accepts that.
        val json = """
            {"boards":[{"key":"consistency_global","name":"Global","scope":"global","period":"halfyearly",
            "joined":false,"my_rank":null,"entries":[],
            "period_starts_at":"2026-01-01T00:00:00.000Z","period_ends_at":"2026-07-01T00:00:00.000Z"}]}
        """.trimIndent()
        val client = FakeApiClient(onGet = { json })
        val viewModel = LeaderboardViewModel(client, NoopHaptics(), UnknownRegionResolver())

        viewModel.load()

        val board = viewModel.state.value.boards[0]
        assertEquals("2026-01-01T00:00:00Z", board.periodStartsAt?.let { java.time.Instant.parse(it) }?.toString())
        assertEquals("2026-07-01T00:00:00Z", board.periodEndsAt?.let { java.time.Instant.parse(it) }?.toString())
    }

    @Test
    fun `load tolerates a lifetime board's null period bounds`() = runTest {
        // A `lifetime` board's bounds are genuinely absent (explicit `null` on
        // the wire, per `periodBoundsFor`), not an omitted key — this must not
        // fail the whole board's decode.
        val json = """
            {"boards":[{"key":"old_board","name":"Old Board","scope":"global","period":"lifetime",
            "joined":false,"my_rank":null,"entries":[],
            "period_starts_at":null,"period_ends_at":null}]}
        """.trimIndent()
        val client = FakeApiClient(onGet = { json })
        val viewModel = LeaderboardViewModel(client, NoopHaptics(), UnknownRegionResolver())

        viewModel.load()

        val board = viewModel.state.value.boards[0]
        assertEquals(null, board.periodStartsAt)
        assertEquals(null, board.periodEndsAt)
    }

    @Test
    fun `load decodes cleanly when the period bound keys are absent entirely`() = runTest {
        // Belt-and-suspenders against a server that omits the keys outright
        // rather than sending explicit nulls.
        val client = FakeApiClient(onGet = { boardJson }) // boardJson has neither key
        val viewModel = LeaderboardViewModel(client, NoopHaptics(), UnknownRegionResolver())

        viewModel.load()

        val board = viewModel.state.value.boards[0]
        assertEquals(null, board.periodStartsAt)
        assertEquals(null, board.periodEndsAt)
    }

    @Test
    fun `load surfaces error on failure`() = runTest {
        val client = FakeApiClient(onGet = { throw RuntimeException("unauthorized") })
        val viewModel = LeaderboardViewModel(client, NoopHaptics(), UnknownRegionResolver())

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
        val viewModel = LeaderboardViewModel(client, NoopHaptics(), UnknownRegionResolver())

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
        val viewModel = LeaderboardViewModel(client, haptics, UnknownRegionResolver())

        viewModel.join("weekly_fajr", publishName = false, city = null)
        assertEquals(1, haptics.targetReachedCount)

        val failingClient = FakeApiClient(onGet = { boardJson }, onPostRaw = { _, _ -> throw RuntimeException("offline") })
        val failingViewModel = LeaderboardViewModel(failingClient, haptics, UnknownRegionResolver())
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
        val viewModel = LeaderboardViewModel(client, NoopHaptics(), UnknownRegionResolver())

        viewModel.leave("weekly_fajr")

        assertEquals("v1/leaderboards/weekly_fajr/leave", leavePath)
        assertFalse(viewModel.state.value.boards[0].joined)
    }
}
