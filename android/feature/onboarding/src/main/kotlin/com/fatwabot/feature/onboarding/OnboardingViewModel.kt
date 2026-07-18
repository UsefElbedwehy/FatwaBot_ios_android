package com.fatwabot.feature.onboarding

import androidx.lifecycle.ViewModel
import com.fatwabot.core.common.OnboardingCompletionStore
import com.fatwabot.core.network.AccountProvider
import com.fatwabot.core.network.AccountServicing
import com.fatwabot.core.network.ProviderCredentialProviding
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * The screens of the value-first onboarding flow (docs/features/onboarding.md).
 * SIGN_IN is last on purpose — accounts are optional and must never gate the
 * app (docs/features/accounts.md).
 */
enum class OnboardingStep {
    WELCOME, HIGHLIGHTS, LOCATION_PRIMING, NOTIFICATION_PRIMING, SIGN_IN
}

/**
 * State machine for onboarding. Unlike iOS, Android's runtime-permission
 * dialogs can only be launched from a Composable (`rememberLauncherForActivityResult`),
 * so this ViewModel owns navigation + completion-persistence only — the
 * Composable itself triggers the actual OS permission prompts and then calls
 * back into [advance]/[finish].
 */
@HiltViewModel
class OnboardingViewModel @Inject constructor(
    private val completionStore: OnboardingCompletionStore,
    private val account: AccountServicing,
    private val credentials: ProviderCredentialProviding,
) : ViewModel() {
    private val _step = MutableStateFlow(OnboardingStep.WELCOME)
    val step: StateFlow<OnboardingStep> = _step.asStateFlow()

    private val _isSigningIn = MutableStateFlow(false)
    val isSigningIn: StateFlow<Boolean> = _isSigningIn.asStateFlow()

    private val _signInFailed = MutableStateFlow(false)
    val signInFailed: StateFlow<Boolean> = _signInFailed.asStateFlow()

    private var finished = false

    /** Providers whose SDK is actually wired on this build (Apple has none on Android). */
    val signInOptions: List<AccountProvider> =
        listOf(AccountProvider.APPLE, AccountProvider.GOOGLE).filter(credentials::isConfigured)

    /** Sequences forward; finishes onboarding once past the last step. */
    fun advance() {
        val next = OnboardingStep.entries.getOrNull(_step.value.ordinal + 1)
        when {
            next == null -> finish()
            // Nothing to offer — don't show an empty screen.
            next == OnboardingStep.SIGN_IN && signInOptions.isEmpty() -> finish()
            else -> _step.value = next
        }
    }

    /** "Not now" / "Skip" — never triggers a permission request, just sequences forward. */
    fun skip() = advance()

    /**
     * Links the anonymous identity to [provider], so everything accumulated
     * during onboarding carries over. Returns true when onboarding is complete;
     * a cancel/failure keeps the user on the step instead of silently dropping
     * them into the app.
     */
    suspend fun signIn(provider: AccountProvider): Boolean {
        _isSigningIn.value = true
        _signInFailed.value = false
        val succeeded = runCatching {
            val token = credentials.identityToken(provider)
            account.link(provider, token)
        }.isSuccess
        _isSigningIn.value = false
        if (succeeded) {
            finish()
        } else {
            _signInFailed.value = true
        }
        return succeeded
    }

    /** "Continue as guest" — the app is fully usable without an account. */
    fun continueAsGuest() = finish()

    fun finish() {
        if (finished) return
        finished = true
        completionStore.markCompleted(System.currentTimeMillis() / 1000)
    }
}
