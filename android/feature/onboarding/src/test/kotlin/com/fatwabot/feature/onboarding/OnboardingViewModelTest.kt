package com.fatwabot.feature.onboarding

import com.fatwabot.core.common.OnboardingCompletionStore
import com.fatwabot.core.network.AccountProfile
import com.fatwabot.core.network.AccountProvider
import com.fatwabot.core.network.AccountServicing
import com.fatwabot.core.network.ProviderCredentialProviding
import java.io.File
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

private class FakeAccount(private val shouldFail: Boolean = false) : AccountServicing {
    var linkedProvider: AccountProvider? = null
    override suspend fun me(): AccountProfile = AccountProfile("u1", null, AccountProvider.ANONYMOUS)
    override suspend fun updateDisplayName(name: String?): AccountProfile = me()
    override suspend fun link(provider: AccountProvider, identityToken: String): AccountProfile {
        if (shouldFail) throw IllegalStateException("link failed")
        linkedProvider = provider
        return AccountProfile("u1", null, provider)
    }
}

private class FakeCredentials(
    private val configured: Set<AccountProvider> = setOf(AccountProvider.GOOGLE),
    private val shouldFail: Boolean = false,
) : ProviderCredentialProviding {
    override fun isConfigured(provider: AccountProvider): Boolean = provider in configured
    override suspend fun identityToken(provider: AccountProvider): String {
        if (shouldFail) throw IllegalStateException("cancelled")
        return "${provider.wire}.token"
    }
}

class OnboardingViewModelTest {
    private fun store(): OnboardingCompletionStore {
        val file = File.createTempFile("onboarding-completion", ".json").apply { deleteOnExit() }
        return OnboardingCompletionStore(file)
    }

    private fun viewModel(
        s: OnboardingCompletionStore = store(),
        account: AccountServicing = FakeAccount(),
        credentials: ProviderCredentialProviding = FakeCredentials(),
    ) = OnboardingViewModel(s, account, credentials)

    @Test
    fun `starts at welcome`() {
        assertEquals(OnboardingStep.WELCOME, viewModel().step.value)
    }

    @Test
    fun `advance walks through the priming steps`() {
        val vm = viewModel()
        vm.advance()
        assertEquals(OnboardingStep.HIGHLIGHTS, vm.step.value)
        vm.advance()
        assertEquals(OnboardingStep.LOCATION_PRIMING, vm.step.value)
        vm.advance()
        assertEquals(OnboardingStep.NOTIFICATION_PRIMING, vm.step.value)
    }

    /** Sign-in comes after the permission steps, never before. */
    @Test
    fun `sign-in is the last step when a provider is configured`() {
        val s = store()
        val vm = viewModel(s)
        repeat(4) { vm.advance() }
        assertEquals(OnboardingStep.SIGN_IN, vm.step.value)
        assertFalse("must not finish before the user answers", s.isCompleted())
    }

    /** With nothing wired we must not show an empty screen. */
    @Test
    fun `step is skipped entirely when no provider is configured`() {
        val s = store()
        val vm = viewModel(s, credentials = FakeCredentials(configured = emptySet()))
        repeat(4) { vm.advance() }
        assertTrue(s.isCompleted())
    }

    @Test
    fun `successful sign-in links the provider and finishes`() = runTest {
        val s = store()
        val account = FakeAccount()
        val vm = viewModel(s, account = account)

        assertTrue(vm.signIn(AccountProvider.GOOGLE))

        assertEquals(AccountProvider.GOOGLE, account.linkedProvider)
        assertTrue(s.isCompleted())
        assertFalse(vm.signInFailed.value)
        assertFalse(vm.isSigningIn.value)
    }

    /** A cancelled/failed sign-in must NOT drop the user into the app. */
    @Test
    fun `failed sign-in keeps the user on the step`() = runTest {
        val s = store()
        val vm = viewModel(s, credentials = FakeCredentials(shouldFail = true))

        assertFalse(vm.signIn(AccountProvider.GOOGLE))

        assertFalse("onboarding must not complete on failure", s.isCompleted())
        assertTrue(vm.signInFailed.value)
        assertFalse(vm.isSigningIn.value)
    }

    /** The account is always optional. */
    @Test
    fun `continue as guest finishes without linking`() {
        val s = store()
        val account = FakeAccount()
        viewModel(s, account = account).continueAsGuest()

        assertTrue(s.isCompleted())
        assertEquals(null, account.linkedProvider)
    }

    @Test
    fun `skip from location priming does not mark completion and still advances`() {
        val s = store()
        val vm = viewModel(s)
        vm.advance()
        vm.advance()

        vm.skip()

        assertEquals(OnboardingStep.NOTIFICATION_PRIMING, vm.step.value)
        assertFalse(s.isCompleted())
    }

    @Test
    fun `finish marks completion and is idempotent`() {
        val s = store()
        val vm = viewModel(s)

        vm.finish()
        vm.finish()

        assertTrue(s.isCompleted())
    }
}
