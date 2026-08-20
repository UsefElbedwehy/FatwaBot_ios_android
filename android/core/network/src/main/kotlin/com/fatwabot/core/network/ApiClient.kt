package com.fatwabot.core.network

import java.io.IOException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.OkHttpClient
import okhttp3.Request

/** Client context headers sent on every request (parity with iOS ClientContext). */
data class ClientContext(
    val platform: String = "android",
    val appVersion: String,
    val locale: String,
)

sealed class ApiException(message: String) : Exception(message) {
    data class Transport(val detail: String) : ApiException("transport: $detail")
    data class Server(val statusCode: Int, val code: String?) : ApiException("server $statusCode ($code)")
    data class Decoding(val detail: String) : ApiException("decoding: $detail")
}

/** Pulls `error.code` out of the standard `{error:{code,message}}` envelope
 * (see backend/functions/api/http.ts apiError) — shared by [ApiClient] and
 * [AuthenticatedApiClient] so a caller can distinguish e.g. `ai_unavailable`
 * from any other 503/500, mirroring iOS `APIError.server(statusCode:code:)`. */
internal fun extractErrorCode(body: String): String? =
    runCatching { Json.parseToJsonElement(body) }.getOrNull()?.let { el ->
        runCatching {
            (el as? kotlinx.serialization.json.JsonObject)
                ?.get("error")?.let { err ->
                    (err as? kotlinx.serialization.json.JsonObject)?.get("code")
                        ?.let { c -> (c as? kotlinx.serialization.json.JsonPrimitive)?.content }
                }
        }.getOrNull()
    }

/** Read path of the versioned REST API (ADR-0002) — mirror of iOS APIClient. */
interface ApiClientProtocol {
    suspend fun getRaw(path: String, query: Map<String, String> = emptyMap()): String
}

class ApiClient(
    private val baseUrl: String,
    private val context: ClientContext,
    private val http: OkHttpClient = OkHttpClient(),
) : ApiClientProtocol {

    override suspend fun getRaw(path: String, query: Map<String, String>): String =
        withContext(Dispatchers.IO) {
            val url = baseUrl.trimEnd('/').toHttpUrl().newBuilder()
                .apply {
                    path.trim('/').split('/').forEach(::addPathSegment)
                    query.forEach { (k, v) -> addQueryParameter(k, v) }
                }
                .build()

            val request = Request.Builder()
                .url(url)
                .header("x-client-platform", context.platform)
                .header("x-client-version", context.appVersion)
                .header("x-client-locale", context.locale)
                .build()

            val response = try {
                http.newCall(request).execute()
            } catch (e: IOException) {
                throw ApiException.Transport(e.message ?: "io error")
            }
            response.use {
                val body = it.body?.string().orEmpty()
                if (!it.isSuccessful) throw ApiException.Server(it.code, extractErrorCode(body))
                body
            }
        }
}
