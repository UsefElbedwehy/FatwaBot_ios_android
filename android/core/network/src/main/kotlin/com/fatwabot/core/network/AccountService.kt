package com.fatwabot.core.network

import java.util.UUID
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

/** The identity kinds the backend recognises (docs/features/accounts.md). */
enum class AccountProvider(val wire: String) {
    ANONYMOUS("anonymous"),
    APPLE("apple"),
    GOOGLE("google"),
    ;

    companion object {
        fun fromWire(value: String?): AccountProvider =
            entries.firstOrNull { it.wire == value } ?: ANONYMOUS
    }
}

/** Snapshot of the current account from GET /v1/me. */
data class AccountProfile(
    val userId: String,
    val displayName: String?,
    val provider: AccountProvider,
) {
    val isSignedIn: Boolean get() = provider != AccountProvider.ANONYMOUS
}

sealed class AccountException(message: String) : Exception(message) {
    /** Provider identity already linked to a different account (HTTP 409). */
    object AlreadyLinked : AccountException("already_linked")
    object NotLinkable : AccountException("not_linkable")
}

/** Reads and mutates the signed-in account. Mirror of iOS AccountService. */
interface AccountServicing {
    suspend fun me(): AccountProfile
    suspend fun updateDisplayName(name: String?): AccountProfile
    suspend fun link(provider: AccountProvider, identityToken: String): AccountProfile
}

@Serializable
private data class MeDto(
    @SerialName("user_id") val userId: String,
    @SerialName("display_name") val displayName: String? = null,
    val provider: String? = null,
)

class AccountService(
    private val client: AuthenticatedApiClientProtocol,
) : AccountServicing {
    private val json = Json { ignoreUnknownKeys = true }

    override suspend fun me(): AccountProfile {
        val dto = json.decodeFromString(MeDto.serializer(), client.getRaw("v1/me"))
        return AccountProfile(dto.userId, dto.displayName, AccountProvider.fromWire(dto.provider))
    }

    override suspend fun updateDisplayName(name: String?): AccountProfile {
        val value = name?.trim()?.ifEmpty { null }
        val body = JsonObject(mapOf("display_name" to (value?.let { JsonPrimitive(it) } ?: JsonNull)))
        client.patchRaw("v1/me/profile", body.toString())
        return me()
    }

    override suspend fun link(provider: AccountProvider, identityToken: String): AccountProfile {
        if (provider != AccountProvider.APPLE && provider != AccountProvider.GOOGLE) {
            throw AccountException.NotLinkable
        }
        val body = buildJsonObject {
            put("provider", provider.wire)
            put("identity_token", identityToken)
        }
        try {
            client.postRaw("v1/auth/link", body.toString())
        } catch (e: ApiException.Server) {
            if (e.statusCode == 409) throw AccountException.AlreadyLinked
            throw e
        }
        return me()
    }
}

/** Persists the dev sign-in subject so re-signing reuses the same account. */
interface SubjectStore {
    fun load(): String?
    fun save(value: String)
}

class InMemorySubjectStore(private var value: String? = null) : SubjectStore {
    override fun load(): String? = value
    override fun save(value: String) { this.value = value }
}

/**
 * Obtains a provider identity token for POST /v1/auth/link. The seam that keeps
 * the account feature buildable before a Google OAuth client / Play Integrity
 * setup exists (mirrors iOS ProviderCredentialProviding + the backend dev
 * verifier). The stub returns a stable per-install token the backend accepts.
 */
interface ProviderCredentialProviding {
    fun isConfigured(provider: AccountProvider): Boolean
    suspend fun identityToken(provider: AccountProvider): String
}

class StubProviderCredentialProvider(
    private val store: SubjectStore,
) : ProviderCredentialProviding {
    override fun isConfigured(provider: AccountProvider): Boolean =
        provider == AccountProvider.APPLE || provider == AccountProvider.GOOGLE

    override suspend fun identityToken(provider: AccountProvider): String {
        require(provider == AccountProvider.APPLE || provider == AccountProvider.GOOGLE)
        val subject = store.load() ?: "dev-${UUID.randomUUID().toString().take(12)}".also(store::save)
        return "${provider.wire}.$subject"
    }
}
