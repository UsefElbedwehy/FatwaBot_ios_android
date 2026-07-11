package com.fatwabot.core.network

import android.content.Context
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import com.fatwabot.core.common.AuthTokenStoring
import com.fatwabot.core.common.AuthTokens
import kotlinx.serialization.json.Json

/** Real secure-storage-backed token store (ADR-0004) — Android Keystore via
 * EncryptedSharedPreferences, the Keychain-equivalent on this platform. */
class EncryptedPrefsAuthTokenStore(context: Context) : AuthTokenStoring {
    private val json = Json { ignoreUnknownKeys = true }
    private val masterKey = MasterKey.Builder(context)
        .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
        .build()
    private val prefs = EncryptedSharedPreferences.create(
        context,
        "fatwabot_auth_tokens",
        masterKey,
        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
    )

    override fun load(): AuthTokens? =
        prefs.getString(KEY, null)?.let { runCatching { json.decodeFromString<AuthTokens>(it) }.getOrNull() }

    override fun save(tokens: AuthTokens) {
        prefs.edit().putString(KEY, json.encodeToString(AuthTokens.serializer(), tokens)).apply()
    }

    override fun clear() {
        prefs.edit().remove(KEY).apply()
    }

    private companion object {
        const val KEY = "tokens"
    }
}
