package com.fatwabot.app.push

import com.fatwabot.core.network.AuthenticatedApiClientProtocol
import javax.inject.Inject
import javax.inject.Singleton
import org.json.JSONObject

/**
 * Registers this device's FCM push token with the backend
 * (PATCH /v1/me/push-token). Uses the authenticated client so the anonymous
 * identity + bearer token are acquired/refreshed transparently. Best-effort:
 * failures are swallowed (the token re-registers on next app start / onNewToken).
 */
@Singleton
class PushTokenRegistrar @Inject constructor(
    private val client: AuthenticatedApiClientProtocol,
) {
    suspend fun register(token: String) {
        val body = JSONObject().put("push_token", token).toString()
        runCatching { client.patchRaw("/v1/me/push-token", body) }
    }
}
