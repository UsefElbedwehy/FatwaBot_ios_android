package com.fatwabot.core.network

import com.fatwabot.core.common.AuthTokens
import com.fatwabot.core.common.InMemoryAuthTokenStore
import kotlinx.coroutines.test.runTest
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class AuthServiceTest {
    private lateinit var server: MockWebServer
    private var now = 1_000_000L
    private val device = DeviceInfo(platform = "android", appVersion = "1.0.0", locale = "en", timezone = "UTC")

    @Before
    fun setUp() {
        server = MockWebServer()
        server.start()
    }

    @After
    fun tearDown() {
        server.shutdown()
    }

    private fun service(store: InMemoryAuthTokenStore = InMemoryAuthTokenStore()) = AuthService(
        baseUrl = server.url("/").toString(),
        device = device,
        store = store,
        nowEpochSeconds = { now },
    )

    @Test
    fun firstCallSignsInAnonymously() = runTest {
        server.enqueue(
            MockResponse().setBody(
                """{"user_id":"u1","kind":"anonymous","access_token":"at1","expires_in":3600,"refresh_token":"rt1"}""",
            ),
        )

        val token = service().validAccessToken()

        assertEquals("at1", token)
        val request = server.takeRequest()
        assertEquals("/v1/auth/anonymous", request.path)
        assertTrue(request.body.readUtf8().contains("\"platform\":\"android\""))
    }

    @Test
    fun cachedTokenIsReusedWhenNotNearExpiry() = runTest {
        val store = InMemoryAuthTokenStore(
            AuthTokens(userId = "u1", accessToken = "cached", refreshToken = "rt1", expiresAtEpochSeconds = now + 3600),
        )

        val token = service(store).validAccessToken()

        assertEquals("cached", token)
        assertEquals(0, server.requestCount)
    }

    @Test
    fun nearExpiryTokenTriggersRefresh() = runTest {
        val store = InMemoryAuthTokenStore(
            AuthTokens(userId = "u1", accessToken = "stale", refreshToken = "rt1", expiresAtEpochSeconds = now + 10),
        )
        server.enqueue(
            MockResponse().setBody(
                """{"user_id":"u1","kind":"anonymous","access_token":"at2","expires_in":3600,"refresh_token":"rt2"}""",
            ),
        )

        val token = service(store).validAccessToken()

        assertEquals("at2", token)
        val request = server.takeRequest()
        assertEquals("/v1/auth/refresh", request.path)
        assertTrue(request.body.readUtf8().contains("rt1"))
    }

    @Test
    fun refreshRejectionFallsBackToFreshAnonymousSignIn() = runTest {
        val store = InMemoryAuthTokenStore(
            AuthTokens(userId = "u1", accessToken = "stale", refreshToken = "bad", expiresAtEpochSeconds = now + 10),
        )
        server.enqueue(MockResponse().setResponseCode(401))
        server.enqueue(
            MockResponse().setBody(
                """{"user_id":"u2","kind":"anonymous","access_token":"at3","expires_in":3600,"refresh_token":"rt3"}""",
            ),
        )

        val token = service(store).validAccessToken()

        assertEquals("at3", token)
        assertEquals("/v1/auth/refresh", server.takeRequest().path)
        assertEquals("/v1/auth/anonymous", server.takeRequest().path)
    }

    @Test
    fun invalidateAndRefreshForcesNewRefreshCall() = runTest {
        val store = InMemoryAuthTokenStore(
            AuthTokens(userId = "u1", accessToken = "at1", refreshToken = "rt1", expiresAtEpochSeconds = now + 3600),
        )
        server.enqueue(
            MockResponse().setBody(
                """{"user_id":"u1","kind":"anonymous","access_token":"at2","expires_in":3600,"refresh_token":"rt2"}""",
            ),
        )

        val token = service(store).invalidateAndRefresh()

        assertEquals("at2", token)
        assertEquals("/v1/auth/refresh", server.takeRequest().path)
    }
}
