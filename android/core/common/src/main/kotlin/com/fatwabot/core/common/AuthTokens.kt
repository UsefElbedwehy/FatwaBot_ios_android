package com.fatwabot.core.common

import kotlinx.serialization.Serializable

/**
 * Session tokens from /v1/auth/{anonymous,refresh,apple,google} (ADR-0004).
 * Clients treat accessToken as opaque; refreshToken is single-use.
 */
@Serializable
data class AuthTokens(
    val userId: String,
    val accessToken: String,
    val refreshToken: String,
    val expiresAtEpochSeconds: Long,
)

/**
 * Persistence boundary for tokens — EncryptedSharedPreferences in production
 * (mirrors iOS Keychain), in-memory for tests/previews.
 */
interface AuthTokenStoring {
    fun load(): AuthTokens?
    fun save(tokens: AuthTokens)
    fun clear()
}

class InMemoryAuthTokenStore(initial: AuthTokens? = null) : AuthTokenStoring {
    private var tokens: AuthTokens? = initial

    override fun load(): AuthTokens? = tokens
    override fun save(tokens: AuthTokens) { this.tokens = tokens }
    override fun clear() { tokens = null }
}
