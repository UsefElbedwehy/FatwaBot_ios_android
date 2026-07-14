package com.fatwabot.core.network

import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

private class FakeAuthedClient : AuthenticatedApiClientProtocol {
    val responses = mutableMapOf<String, String>()
    val errors = mutableMapOf<String, Throwable>()
    val calls = mutableListOf<String>()

    private fun reply(key: String): String {
        calls += key
        errors[key]?.let { throw it }
        return responses[key] ?: "{}"
    }

    override suspend fun getRaw(path: String, query: Map<String, String>): String = reply("GET $path")
    override suspend fun postRaw(path: String, jsonBody: String): String = reply("POST $path")
    override suspend fun postEmptyRaw(path: String): String = reply("POST $path")
    override suspend fun patchRaw(path: String, jsonBody: String): String = reply("PATCH $path")
    override suspend fun deleteRaw(path: String): String = reply("DELETE $path")
}

class AccountServiceTest {
    @Test
    fun `me decodes provider and display name`() = runTest {
        val client = FakeAuthedClient()
        client.responses["GET v1/me"] = """{"user_id":"u1","display_name":"Zaid","provider":"apple"}"""
        val profile = AccountService(client).me()
        assertEquals("u1", profile.userId)
        assertEquals("Zaid", profile.displayName)
        assertEquals(AccountProvider.APPLE, profile.provider)
        assertTrue(profile.isSignedIn)
    }

    @Test
    fun `me defaults to anonymous when provider missing`() = runTest {
        val client = FakeAuthedClient()
        client.responses["GET v1/me"] = """{"user_id":"u1","display_name":null}"""
        val profile = AccountService(client).me()
        assertEquals(AccountProvider.ANONYMOUS, profile.provider)
        assertTrue(!profile.isSignedIn)
    }

    @Test
    fun `updateDisplayName patches then reloads`() = runTest {
        val client = FakeAuthedClient()
        client.responses["GET v1/me"] = """{"user_id":"u1","display_name":"Sara","provider":"anonymous"}"""
        val profile = AccountService(client).updateDisplayName("  Sara  ")
        assertEquals("Sara", profile.displayName)
        assertEquals(listOf("PATCH v1/me/profile", "GET v1/me"), client.calls)
    }

    @Test
    fun `link posts then reloads`() = runTest {
        val client = FakeAuthedClient()
        client.responses["GET v1/me"] = """{"user_id":"u1","display_name":"Sara","provider":"google"}"""
        val profile = AccountService(client).link(AccountProvider.GOOGLE, "google.dev-abc")
        assertEquals(AccountProvider.GOOGLE, profile.provider)
        assertEquals(listOf("POST v1/auth/link", "GET v1/me"), client.calls)
    }

    @Test
    fun `link maps 409 to AlreadyLinked`() = runTest {
        val client = FakeAuthedClient()
        client.errors["POST v1/auth/link"] = ApiException.Server(409, "already_linked")
        try {
            AccountService(client).link(AccountProvider.APPLE, "apple.dev-abc")
            fail("expected AlreadyLinked")
        } catch (e: AccountException.AlreadyLinked) {
            // expected
        }
    }

    @Test
    fun `link rejects anonymous provider`() = runTest {
        try {
            AccountService(FakeAuthedClient()).link(AccountProvider.ANONYMOUS, "x")
            fail("expected NotLinkable")
        } catch (e: AccountException.NotLinkable) {
            // expected
        }
    }

    @Test
    fun `stub credential produces stable subject`() = runTest {
        val provider = StubProviderCredentialProvider(InMemorySubjectStore())
        val a = provider.identityToken(AccountProvider.APPLE)
        val b = provider.identityToken(AccountProvider.APPLE)
        assertEquals(a, b)
        assertTrue(a.startsWith("apple."))
        assertTrue(provider.isConfigured(AccountProvider.GOOGLE))
    }
}
