package com.fatwabot.app.auth

import android.content.Context
import androidx.credentials.CredentialManager
import androidx.credentials.GetCredentialRequest
import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.exceptions.GetCredentialException
import com.fatwabot.core.network.AccountProvider
import com.fatwabot.core.network.ProviderCredentialProviding
import com.google.android.libraries.identity.googleid.GetGoogleIdOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential

/** Raised when the user dismisses the Google sheet — surfaced as a no-op. */
class SignInCancelledException : Exception("cancelled")

/**
 * Real Google Sign-In through Credential Manager. Returns the Google **ID
 * token**, verified server-side against Google's JWKS.
 *
 * `serverClientId` is the **web** OAuth client id on purpose: that becomes the
 * token's `aud`, which is what the backend's GoogleIdentityVerifier accepts
 * (it allows the web and iOS client ids).
 */
class GoogleCredentialProvider(
    private val appContext: Context,
    private val activityHolder: CurrentActivityHolder,
    private val serverClientId: String = WEB_CLIENT_ID,
) : ProviderCredentialProviding {

    companion object {
        /** Public identifier (ships in the app) — Firebase project fatwabot-5f898. */
        const val WEB_CLIENT_ID =
            "665767164439-kgoe4prr2dsiv9ih9h02250cm4p5kbtb.apps.googleusercontent.com"
    }

    override fun isConfigured(provider: AccountProvider): Boolean =
        provider == AccountProvider.GOOGLE

    override suspend fun identityToken(provider: AccountProvider): String {
        require(provider == AccountProvider.GOOGLE) { "GoogleCredentialProvider handles Google only" }
        val activity = activityHolder.current
            ?: throw IllegalStateException("No foreground activity to present Google Sign-In from")

        val option = GetGoogleIdOption.Builder()
            .setServerClientId(serverClientId)
            // Also offer accounts that haven't authorised the app yet, so a
            // first-time signer isn't shown an empty sheet.
            .setFilterByAuthorizedAccounts(false)
            .build()
        val request = GetCredentialRequest.Builder().addCredentialOption(option).build()

        try {
            val response = CredentialManager.create(appContext).getCredential(activity, request)
            val credential = GoogleIdTokenCredential.createFrom(response.credential.data)
            return credential.idToken
        } catch (e: GetCredentialCancellationException) {
            throw SignInCancelledException()
        } catch (e: GetCredentialException) {
            throw IllegalStateException("Google Sign-In failed: ${e.message}", e)
        }
    }
}

/**
 * Routes providers to their real implementation. Sign in with Apple has no
 * native Android SDK, so it reports unconfigured and the UI hides that button
 * (a web-based Apple flow could be added later).
 */
class CompositeCredentialProvider(
    private val google: ProviderCredentialProviding,
) : ProviderCredentialProviding {

    override fun isConfigured(provider: AccountProvider): Boolean =
        provider == AccountProvider.GOOGLE && google.isConfigured(provider)

    override suspend fun identityToken(provider: AccountProvider): String {
        require(provider == AccountProvider.GOOGLE) { "Only Google sign-in is available on Android" }
        return google.identityToken(provider)
    }
}
