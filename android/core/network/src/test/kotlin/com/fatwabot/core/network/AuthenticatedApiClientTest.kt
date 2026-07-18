package com.fatwabot.core.network

import kotlinx.coroutines.test.runTest
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

private class FakeTokenProvider(
    private var current: String,
    private val refreshed: String? = null,
) : AuthTokenProviding {
    var refreshCalls = 0
        private set

    override suspend fun validAccessToken(): String = current

    override suspend fun invalidateAndRefresh(): String {
        refreshCalls++
        current = refreshed ?: current
        return current
    }
}

class AuthenticatedApiClientTest {
    private lateinit var server: MockWebServer

    @Before
    fun setUp() {
        server = MockWebServer()
        server.start()
    }

    @After
    fun tearDown() {
        server.shutdown()
    }

    private fun client(tokens: AuthTokenProviding) = AuthenticatedApiClient(
        baseUrl = server.url("/").toString(),
        context = ClientContext(appVersion = "1.0.0", locale = "en"),
        tokens = tokens,
    )

    @Test
    fun getAttachesBearerTokenAndHeaders() = runTest {
        server.enqueue(MockResponse().setBody("""{"ok":true}"""))

        val body = client(FakeTokenProvider("at1")).getRaw("v1/me")

        assertEquals("""{"ok":true}""", body)
        val request = server.takeRequest()
        assertEquals("Bearer at1", request.getHeader("Authorization"))
        assertEquals("android", request.getHeader("x-client-platform"))
    }

    @Test
    fun postSendsJsonBody() = runTest {
        server.enqueue(MockResponse().setBody("""{"ok":true}"""))

        client(FakeTokenProvider("at1")).postRaw("v1/me/profile", """{"display_name":"Zeko"}""")

        val request = server.takeRequest()
        assertEquals("POST", request.method)
        assertTrue(request.body.readUtf8().contains("Zeko"))
    }

    @Test
    fun on401RefreshesAndRetriesOnce() = runTest {
        server.enqueue(MockResponse().setResponseCode(401))
        server.enqueue(MockResponse().setBody("""{"ok":true}"""))
        val tokens = FakeTokenProvider("stale", refreshed = "fresh")

        val body = client(tokens).getRaw("v1/me")

        assertEquals("""{"ok":true}""", body)
        assertEquals(1, tokens.refreshCalls)
        server.takeRequest()
        val retry = server.takeRequest()
        assertEquals("Bearer fresh", retry.getHeader("Authorization"))
    }

    @Test
    fun serverErrorAfterRetryThrows() = runTest {
        server.enqueue(MockResponse().setResponseCode(401))
        server.enqueue(MockResponse().setResponseCode(401))
        val tokens = FakeTokenProvider("stale", refreshed = "still-bad")

        var thrown: ApiException? = null
        try {
            client(tokens).getRaw("v1/me")
        } catch (e: ApiException) {
            thrown = e
        }

        assertTrue(thrown is ApiException.Server)
        assertEquals(401, (thrown as ApiException.Server).statusCode)
    }
}
