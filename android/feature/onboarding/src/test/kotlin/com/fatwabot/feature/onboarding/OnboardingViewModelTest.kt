package com.fatwabot.feature.onboarding

import com.fatwabot.core.common.OnboardingCompletionStore
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class OnboardingViewModelTest {
    private fun store(): OnboardingCompletionStore {
        val file = File.createTempFile("onboarding-completion", ".json").apply { deleteOnExit() }
        return OnboardingCompletionStore(file)
    }

    @Test
    fun `starts at welcome`() {
        val viewModel = OnboardingViewModel(store())
        assertEquals(OnboardingStep.WELCOME, viewModel.step.value)
    }

    @Test
    fun `advance walks through all four steps`() {
        val viewModel = OnboardingViewModel(store())

        viewModel.advance()
        assertEquals(OnboardingStep.HIGHLIGHTS, viewModel.step.value)
        viewModel.advance()
        assertEquals(OnboardingStep.LOCATION_PRIMING, viewModel.step.value)
        viewModel.advance()
        assertEquals(OnboardingStep.NOTIFICATION_PRIMING, viewModel.step.value)
    }

    @Test
    fun `advancing past the last step marks completion`() {
        val s = store()
        val viewModel = OnboardingViewModel(s)
        repeat(3) { viewModel.advance() } // now at NOTIFICATION_PRIMING

        viewModel.advance()

        assertTrue(s.isCompleted())
    }

    @Test
    fun `skip from location priming does not mark completion and still advances`() {
        val s = store()
        val viewModel = OnboardingViewModel(s)
        viewModel.advance() // highlights
        viewModel.advance() // locationPriming

        viewModel.skip()

        assertEquals(OnboardingStep.NOTIFICATION_PRIMING, viewModel.step.value)
        assertFalse(s.isCompleted())
    }

    @Test
    fun `finish marks completion and is idempotent`() {
        val s = store()
        val viewModel = OnboardingViewModel(s)

        viewModel.finish()
        viewModel.finish()

        assertTrue(s.isCompleted())
    }
}
