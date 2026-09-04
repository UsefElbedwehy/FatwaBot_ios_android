package com.fatwabot.core.network

import com.fatwabot.core.common.AuthTokenStoring
import com.fatwabot.core.common.AuthTokens
import java.io.IOException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody

/** Device metadata sent on anonymous sign-in (DeviceRegistration, api.v1.yaml). */
data class DeviceInfo(
    val platform: String,
    val appVersion: String,
    val locale: String,
    val timezone: String,
)

@Serializable
private data class DeviceRegistrationDto(
    val platform: String,
    @SerialName("app_version") val appVersion: String,
    val locale: String,
    val timezone: String,
)

@Serializable
private data class AnonymousSignInRequest(val device: DeviceRegistrationDto)

@Serializable
private data class RefreshRequest(@SerialName("refresh_token") val refreshToken: String)

@Serializable
private data class TokenResponseDto(
    @SerialName("user_id") val userId: String,
    val kind: String,
    @SerialName("access_token") val accessToken: String,
    @SerialName("expires_in") val expiresIn: Long,
    @SerialName("refresh_token") val refreshToken: String,
)

/** Boundary matching iOS AuthTokenProviding — callers never see raw tokens. */
interface AuthTokenProviding {
    suspend fun validAccessToken(): String
    suspend fun invalidateAndRefresh(): String
}

private const val REFRESH_BUFFER_SECONDS = 60L

/** Anonymous sign-in + refresh (ADR-0004) — mirror of iOS AuthService. Proactively
 * refreshes REFRESH_BUFFER_SECONDS before expiry; falls back to a fresh anonymous
 * sign-in if the stored refresh token is rejected. */
class AuthService(
    private val baseUrl: String,
    private val device: DeviceInfo,
    private val store: AuthTokenStoring,
    private val http: OkHttpClient = defaultHttpClient(),
    private val nowEpochSeconds: () -> Long,
) : AuthTokenProviding {
    private val json = Json { ignoreUnknownKeys = true }
    private val mutex = Mutex()
    private val jsonMedia = "application/json".toMediaType()

    override suspend fun validAccessToken(): String = mutex.withLock {
        val cached = store.load()
        if (cached != null && cached.expiresAtEpochSeconds - REFRESH_BUFFER_SECONDS > nowEpochSeconds()) {
            return@withLock cached.accessToken
        }
        refreshOrSignIn(cached)
    }

    override suspend fun invalidateAndRefresh(): String = mutex.withLock {
        refreshOrSignIn(store.load())
    }

    private suspend fun refreshOrSignIn(cached: AuthTokens?): String {
        val refreshed = cached?.refreshToken?.let { runCatching { refresh(it) }.getOrNull() }
        val tokens = refreshed ?: signInAnonymously()
        store.save(tokens)
        return tokens.accessToken
    }

    private suspend fun signInAnonymously(): AuthTokens = withContext(Dispatchers.IO) {
        val body = json.encodeToString(
            AnonymousSignInRequest.serializer(),
            AnonymousSignInRequest(
                DeviceRegistrationDto(
                    platform = device.platform,
                    appVersion = device.appVersion,
                    locale = device.locale,
                    timezone = device.timezone,
                ),
            ),
        )
        post("v1/auth/anonymous", body)
    }

    private suspend fun refresh(refreshToken: String): AuthTokens = withContext(Dispatchers.IO) {
        val body = json.encodeToString(RefreshRequest.serializer(), RefreshRequest(refreshToken))
        post("v1/auth/refresh", body)
    }

    private fun post(path: String, jsonBody: String): AuthTokens {
        val url = baseUrl.trimEnd('/') + "/" + path.trim('/')
        val request = Request.Builder()
            .url(url)
            .post(jsonBody.toRequestBody(jsonMedia))
            .build()

        val response = try {
            http.newCall(request).execute()
        } catch (e: IOException) {
            throw ApiException.Transport(e.message ?: "io error")
        }
        response.use {
            val responseBody = it.body?.string().orEmpty()
            if (!it.isSuccessful) throw ApiException.Server(it.code, null)
            val dto = try {
                json.decodeFromString(TokenResponseDto.serializer(), responseBody)
            } catch (e: Exception) {
                throw ApiException.Decoding(e.message ?: "decode error")
            }
            return AuthTokens(
                userId = dto.userId,
                accessToken = dto.accessToken,
                refreshToken = dto.refreshToken,
                expiresAtEpochSeconds = nowEpochSeconds() + dto.expiresIn,
            )
        }
    }
}
