package com.fatwabot.feature.searchhistory

import com.fatwabot.core.common.HapticsProviding
import com.fatwabot.core.common.NoopHaptics
import com.fatwabot.core.network.AuthenticatedApiClientProtocol
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

private class FakeApiClient(
    private val onGet: () -> String,
    private val onDelete: (String) -> String = { """{"deleted":true}""" },
) : AuthenticatedApiClientProtocol {
    override suspend fun getRaw(path: String, query: Map<String, String>): String = onGet()
    override suspend fun postRaw(path: String, jsonBody: String) = ""
    override suspend fun postEmptyRaw(path: String) = ""
    override suspend fun patchRaw(path: String, jsonBody: String) = ""
    override suspend fun deleteRaw(path: String): String = onDelete(path)
}

class SearchHistoryViewModelTest {
    private val entriesJson = """
        {"entries":[{"id":"1","source":"dua","query_text":"الصلاة","locale":"ar","created_at":"2026-07-07T10:00:00Z"},
        {"id":"2","source":"dua","query_text":"الاستخارة","locale":"ar","created_at":"2026-07-07T09:00:00Z"}]}
    """.trimIndent()

    @Test
    fun `load populates entries from server`() = runTest {
        val client = FakeApiClient(onGet = { entriesJson })
        val viewModel = SearchHistoryViewModel(client, NoopHaptics())

        viewModel.load()

        assertEquals(2, viewModel.state.value.entries.size)
        assertEquals(null, viewModel.state.value.error)
    }

    @Test
    fun `delete removes optimistically and confirms with server`() = runTest {
        var deletePath: String? = null
        val client = FakeApiClient(onGet = { entriesJson }, onDelete = { path -> deletePath = path; """{"deleted":true}""" })
        val viewModel = SearchHistoryViewModel(client, NoopHaptics())
        viewModel.load()
        val target = viewModel.state.value.entries.first { it.id == "1" }

        viewModel.delete(target)

        assertEquals("v1/search-history/1", deletePath)
        assertEquals(1, viewModel.state.value.entries.size)
        assertEquals("2", viewModel.state.value.entries.first().id)
    }

    @Test
    fun `delete rolls back on server failure`() = runTest {
        val client = FakeApiClient(onGet = { entriesJson }, onDelete = { throw RuntimeException("offline") })
        val viewModel = SearchHistoryViewModel(client, NoopHaptics())
        viewModel.load()
        val target = viewModel.state.value.entries.first { it.id == "1" }

        viewModel.delete(target)

        assertEquals(2, viewModel.state.value.entries.size)
        assertNotNull(viewModel.state.value.error)
    }

    @Test
    fun `clear all empties entries on success`() = runTest {
        var clearPath: String? = null
        val client = FakeApiClient(onGet = { entriesJson }, onDelete = { path -> clearPath = path; """{"cleared":true}""" })
        val viewModel = SearchHistoryViewModel(client, NoopHaptics())
        viewModel.load()

        viewModel.clearAll()

        assertEquals("v1/search-history", clearPath)
        assertTrue(viewModel.state.value.entries.isEmpty())
    }

    @Test
    fun `delete and clear all fire a haptic tick`() = runTest {
        val haptics = object : HapticsProviding {
            var tickCount = 0
            override fun tick() { tickCount += 1 }
            override fun targetReached() {}
        }
        val client = FakeApiClient(onGet = { entriesJson })
        val viewModel = SearchHistoryViewModel(client, haptics)
        viewModel.load()
        val target = viewModel.state.value.entries.first { it.id == "1" }

        viewModel.delete(target)
        assertEquals(1, haptics.tickCount)

        viewModel.clearAll()
        assertEquals(2, haptics.tickCount)
    }
}
