package com.fatwabot.core.network

import java.io.IOException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody
import okhttp3.RequestBody.Companion.toRequestBody

private val jsonMedia = "application/json".toMediaType()

/** Authenticated REST surface (bearer + 401-retry-once) — mirror of iOS
 * AuthenticatedAPIClientProtocol. Callers pass/receive raw JSON strings,
 * matching this codebase's existing ApiClientProtocol convention. */
interface AuthenticatedApiClientProtocol {
    suspend fun getRaw(path: String, query: Map<String, String> = emptyMap()): String
    suspend fun postRaw(path: String, jsonBody: String): String
    suspend fun postEmptyRaw(path: String): String
    suspend fun patchRaw(path: String, jsonBody: String): String
    suspend fun deleteRaw(path: String): String
}

class AuthenticatedApiClient(
    private val baseUrl: String,
    private val context: ClientContext,
    private val tokens: AuthTokenProviding,
    private val http: OkHttpClient = defaultHttpClient(),
) : AuthenticatedApiClientProtocol {

    override suspend fun getRaw(path: String, query: Map<String, String>): String =
        execute(path, query, "GET", null)

    override suspend fun postRaw(path: String, jsonBody: String): String =
        execute(path, emptyMap(), "POST", jsonBody.toRequestBody(jsonMedia))

    override suspend fun postEmptyRaw(path: String): String =
        execute(path, emptyMap(), "POST", "".toRequestBody(jsonMedia))

    override suspend fun patchRaw(path: String, jsonBody: String): String =
        execute(path, emptyMap(), "PATCH", jsonBody.toRequestBody(jsonMedia))

    override suspend fun deleteRaw(path: String): String =
        execute(path, emptyMap(), "DELETE", null)

    private suspend fun execute(
        path: String,
        query: Map<String, String>,
        method: String,
        body: RequestBody?,
    ): String = withContext(Dispatchers.IO) {
        val accessToken = tokens.validAccessToken()
        val response = send(path, query, method, body, accessToken)
        if (response.code != 401) return@withContext response.consume()

        val refreshedToken = tokens.invalidateAndRefresh()
        send(path, query, method, body, refreshedToken).consume()
    }

    private fun send(
        path: String,
        query: Map<String, String>,
        method: String,
        body: RequestBody?,
        accessToken: String,
    ): okhttp3.Response {
        val url = baseUrl.trimEnd('/').toHttpUrl().newBuilder()
            .apply {
                path.trim('/').split('/').forEach(::addPathSegment)
                query.forEach { (k, v) -> addQueryParameter(k, v) }
            }
            .build()

        val request = Request.Builder()
            .url(url)
            .method(method, body)
            .header("Authorization", "Bearer $accessToken")
            .header("x-client-platform", context.platform)
            .header("x-client-version", context.appVersion)
            .header("x-client-locale", context.locale)
            .build()

        return try {
            http.newCall(request).execute()
        } catch (e: IOException) {
            throw ApiException.Transport(e.message ?: "io error")
        }
    }

    private fun okhttp3.Response.consume(): String = use {
        val responseBody = it.body?.string().orEmpty()
        if (!it.isSuccessful) throw ApiException.Server(it.code, extractErrorCode(responseBody))
        responseBody
    }
}
