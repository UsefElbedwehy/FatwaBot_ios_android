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
        val viewModel = FatwaSearchViewModel(client, "   ", FatwaSearchMode.GENERAL)

        viewModel.submit()

        assertEquals(FatwaSearchViewModel.Phase.Idle, viewModel.state.value.phase)
    }

    @Test
    fun `submit goes straight to unavailable without a network call when search is disabled`() = runTest {
        val client = FakeApiClient(onPost = { _, _ -> error("must not call the network while search is disabled") })
        val viewModel = FatwaSearchViewModel(client, "سؤال", FatwaSearchMode.FATWA, searchEnabled = false)

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
        val viewModel = FatwaSearchViewModel(client, "  ما حكم كذا  ", FatwaSearchMode.FATWA, searchEnabled = true)

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
        val viewModel = FatwaSearchViewModel(client, "سؤال", FatwaSearchMode.HADITH, searchEnabled = true)

        viewModel.submit()

        assertEquals(FatwaSearchViewModel.Phase.Unavailable, viewModel.state.value.phase)
    }

    @Test
    fun `submit maps other failures to a generic error phase`() = runTest {
        val client = FakeApiClient(onPost = { _, _ -> throw ApiException.Transport("offline") })
        val viewModel = FatwaSearchViewModel(client, "سؤال", FatwaSearchMode.GENERAL, searchEnabled = true)

        viewModel.submit()

        assertTrue(viewModel.state.value.phase is FatwaSearchViewModel.Phase.Error)
    }

    @Test
    fun `reset clears the question and returns to idle`() = runTest {
        val client = FakeApiClient(onPost = { _, _ ->
            """{"answer":"جواب","citations":[],"refused":false,"mode":"general"}"""
        })
        val viewModel = FatwaSearchViewModel(client, "سؤال", FatwaSearchMode.GENERAL, searchEnabled = true)
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
        val viewModel = FatwaSearchViewModel(client, "سؤال بلا مصدر", FatwaSearchMode.GENERAL, searchEnabled = true)

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
        val viewModel = FatwaSearchViewModel(client, "", FatwaSearchMode.GENERAL)

        viewModel.updateQuestion("سؤال جديد")

        assertEquals("سؤال جديد", viewModel.state.value.question)
    }

    @Test
    fun `fatwa is the default mode`() {
        // The client asked for the first filter to be selected on arrival.
        val viewModel = FatwaSearchViewModel(FakeApiClient(onPost = { _, _ -> "" }), "")

        assertEquals(FatwaSearchMode.FATWA, viewModel.state.value.mode)
    }

    @Test
    fun `changing mode clears a result from the previous mode`() = runTest {
        val client = FakeApiClient(onPost = { _, _ -> STRUCTURED_RESPONSE })
        val viewModel = FatwaSearchViewModel(client, "سؤال", FatwaSearchMode.FATWA, searchEnabled = true)
        viewModel.submit()
        assertTrue(viewModel.state.value.phase is FatwaSearchViewModel.Phase.Result)

        viewModel.setMode(FatwaSearchMode.HADITH)

        // A فتوى answer left under the حديث chip would read as an answer to the
        // mode now selected, which it is not.
        assertEquals(FatwaSearchViewModel.Phase.Idle, viewModel.state.value.phase)
        assertEquals(FatwaSearchMode.HADITH, viewModel.state.value.mode)
    }

    @Test
    fun `re-selecting the same mode keeps the result on screen`() = runTest {
        val client = FakeApiClient(onPost = { _, _ -> STRUCTURED_RESPONSE })
        val viewModel = FatwaSearchViewModel(client, "سؤال", FatwaSearchMode.FATWA, searchEnabled = true)
        viewModel.submit()

        viewModel.setMode(FatwaSearchMode.FATWA)

        assertTrue(viewModel.state.value.phase is FatwaSearchViewModel.Phase.Result)
    }

    @Test
    fun `submit sends the mode currently selected, not the one it was built with`() = runTest {
        var sentBody: String? = null
        val client = FakeApiClient(onPost = { _, body -> sentBody = body; STRUCTURED_RESPONSE })
        val viewModel = FatwaSearchViewModel(client, "سؤال", FatwaSearchMode.FATWA, searchEnabled = true)

        viewModel.setMode(FatwaSearchMode.HADITH)
        viewModel.updateQuestion("سؤال")
        viewModel.submit()

        assertTrue(sentBody!!.contains("\"hadith\""))
    }

    @Test
    fun `the structured contract decodes, and an unknown ruling does not crash`() = runTest {
        // `wudu_status` is not a ruling this build knows. An older client must
        // draw no dot rather than fail to parse the whole answer.
        val body = STRUCTURED_RESPONSE.replace("\"haram\"", "\"wudu_status\"")
        val viewModel = FatwaSearchViewModel(
            FakeApiClient(onPost = { _, _ -> body }),
            "سؤال",
            FatwaSearchMode.FATWA,
            searchEnabled = true,
        )

        viewModel.submit()

        val result = viewModel.state.value.phase as FatwaSearchViewModel.Phase.Result
        assertEquals(Ruling.NONE, result.response.ruling)
        assertEquals("خلاصة", result.response.summary)
        assertEquals(1, result.response.scholarAnswers.size)
        assertEquals("ابن عثيمين", result.response.scholarAnswers[0].scholar)
        assertEquals(3, result.response.resources.size)
    }

    @Test
    fun `a pre-M5_1 response still decodes, degrading to the flat answer`() = runTest {
        // The apps ship independently of the backend; one built against the new
        // contract must not break against a server that has not deployed it.
        val old = """{"answer":"نص","citations":[],"refused":false,"mode":"fatwa"}"""
        val viewModel = FatwaSearchViewModel(
            FakeApiClient(onPost = { _, _ -> old }),
            "سؤال",
            FatwaSearchMode.FATWA,
            searchEnabled = true,
        )

        viewModel.submit()

        val result = viewModel.state.value.phase as FatwaSearchViewModel.Phase.Result
        assertEquals("نص", result.response.answer)
        assertEquals(Ruling.NONE, result.response.ruling)
        assertTrue(result.response.scholarAnswers.isEmpty())
    }


    @Test
    fun `a fatwa response can carry hadith fields — the view gates them, not the parser`() = runTest {
        // Observed on device: the model volunteers `hadith` when a fatwa rests
        // on one, which put a takhrij card inside a فتوى answer. The parser
        // keeps them (they are real), and SearchResultView renders them only
        // when the response's own mode is hadith.
        val body = STRUCTURED_RESPONSE.replace(
            "\"citations\": []",
            "\"hadith\": {\"text\":\"نص\",\"grade\":\"صحيح\"}, \"citations\": []",
        )
        val viewModel = FatwaSearchViewModel(
            FakeApiClient(onPost = { _, _ -> body }),
            "سؤال",
            FatwaSearchMode.FATWA,
            searchEnabled = true,
        )

        viewModel.submit()

        val result = viewModel.state.value.phase as FatwaSearchViewModel.Phase.Result
        assertEquals("صحيح", result.response.hadith?.grade)
        assertEquals("fatwa", result.response.mode)
    }
}

private val STRUCTURED_RESPONSE = """
{
  "answer": "نص",
  "summary": "خلاصة",
  "ruling": "haram",
  "scholar_answers": [{"scholar":"ابن عثيمين","answer":"قول","evidence":"دليل"}],
  "resources": [
    {"kind":"book","available":true,"url":null},
    {"kind":"video","available":false,"url":null},
    {"kind":"website","available":false,"url":null}
  ],
  "citations": [],
  "refused": false,
  "mode": "fatwa"
}
"""
