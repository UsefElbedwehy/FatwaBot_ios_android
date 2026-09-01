package com.fatwabot.feature.fatwasearch

import com.fatwabot.core.network.ApiException
import com.fatwabot.core.network.AuthenticatedApiClientProtocol
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

private class FakeApiClient(
    private val onPost: (String, String) -> String,
) : AuthenticatedApiClientProtocol {
    override suspend fun getRaw(path: String, query: Map<String, String>) = throw NotImplementedError("not used in these tests")
    override suspend fun postRaw(path: String, jsonBody: String): String = onPost(path, jsonBody)
    override suspend fun postEmptyRaw(path: String) = throw NotImplementedError("not used in these tests")
    override suspend fun patchRaw(path: String, jsonBody: String) = throw NotImplementedError("not used in these tests")
    override suspend fun deleteRaw(path: String) = throw NotImplementedError("not used in these tests")
}

class FatwaSearchViewModelTest {
    @Test
    fun `submit does nothing on blank question`() = runTest {
        val client = FakeApiClient(onPost = { _, _ -> error("should not call the network for a blank question") })
        val viewModel = FatwaSearchViewModel(client, FatwaSearchMode.GENERAL, "   ")

        viewModel.submit()

        assertEquals(FatwaSearchViewModel.Phase.Idle, viewModel.state.value.phase)
    }

    @Test
    fun `submit goes straight to unavailable without a network call when search is disabled`() = runTest {
        val client = FakeApiClient(onPost = { _, _ -> error("must not call the network while search is disabled") })
        val viewModel = FatwaSearchViewModel(client, FatwaSearchMode.FATWA, "سؤال", searchEnabled = false)

        viewModel.submit()

        assertEquals(FatwaSearchViewModel.Phase.Unavailable, viewModel.state.value.phase)
    }

    @Test
    fun `submit posts the trimmed question and mode and populates the result`() = runTest {
        var capturedPath: String? = null
        var capturedBody: String? = null
        val client = FakeApiClient(onPost = { path, body ->
            capturedPath = path
            capturedBody = body
            """{"answer":"الجواب: ...","citations":[{"chunk_id":"c1","scholar":"ابن عثيمين","source_title":"فتاوى أركان الإسلام","page_number":12,"quoted_text":"نص الاقتباس"}],"refused":false,"mode":"fatwa"}"""
        })
        val viewModel = FatwaSearchViewModel(client, FatwaSearchMode.FATWA, "  ما حكم كذا  ", searchEnabled = true)

        viewModel.submit()

        assertEquals("v1/search", capturedPath)
        assertTrue(capturedBody!!.contains("\"question\":\"ما حكم كذا\""))
        assertTrue(capturedBody!!.contains("\"mode\":\"fatwa\""))
        val phase = viewModel.state.value.phase
        check(phase is FatwaSearchViewModel.Phase.Result)
        assertEquals(1, phase.response.citations.size)
        assertFalse(phase.response.refused)
    }

    @Test
    fun `submit maps a 503 ai_unavailable to the unavailable phase`() = runTest {
        val client = FakeApiClient(onPost = { _, _ -> throw ApiException.Server(503, "ai_unavailable") })
        val viewModel = FatwaSearchViewModel(client, FatwaSearchMode.HADITH, "سؤال", searchEnabled = true)

        viewModel.submit()

        assertEquals(FatwaSearchViewModel.Phase.Unavailable, viewModel.state.value.phase)
    }

    @Test
    fun `submit maps other failures to a generic error phase`() = runTest {
        val client = FakeApiClient(onPost = { _, _ -> throw ApiException.Transport("offline") })
        val viewModel = FatwaSearchViewModel(client, FatwaSearchMode.GENERAL, "سؤال", searchEnabled = true)

        viewModel.submit()

        assertTrue(viewModel.state.value.phase is FatwaSearchViewModel.Phase.Error)
    }

    @Test
    fun `reset clears the question and returns to idle`() = runTest {
        val client = FakeApiClient(onPost = { _, _ ->
            """{"answer":"جواب","citations":[],"refused":false,"mode":"general"}"""
        })
        val viewModel = FatwaSearchViewModel(client, FatwaSearchMode.GENERAL, "سؤال", searchEnabled = true)
        viewModel.submit()

        viewModel.reset()

        assertEquals(FatwaSearchViewModel.Phase.Idle, viewModel.state.value.phase)
        assertEquals("", viewModel.state.value.question)
    }

    @Test
    fun `a refused result still populates the answer message with no citations`() = runTest {
        val client = FakeApiClient(onPost = { _, _ ->
            """{"answer":"لم نجد في مصادرنا الموثوقة ما يجيب عن هذا السؤال.","citations":[],"refused":true,"mode":"general"}"""
        })
        val viewModel = FatwaSearchViewModel(client, FatwaSearchMode.GENERAL, "سؤال بلا مصدر", searchEnabled = true)

        viewModel.submit()

        val phase = viewModel.state.value.phase
        check(phase is FatwaSearchViewModel.Phase.Result)
        assertTrue(phase.response.refused)
        assertTrue(phase.response.citations.isEmpty())
        assertFalse(phase.response.answer.isEmpty())
    }

    @Test
    fun `updateQuestion updates state`() = runTest {
        val client = FakeApiClient(onPost = { _, _ -> error("not used") })
        val viewModel = FatwaSearchViewModel(client, FatwaSearchMode.GENERAL, "")

        viewModel.updateQuestion("سؤال جديد")

        assertEquals("سؤال جديد", viewModel.state.value.question)
    }
}
