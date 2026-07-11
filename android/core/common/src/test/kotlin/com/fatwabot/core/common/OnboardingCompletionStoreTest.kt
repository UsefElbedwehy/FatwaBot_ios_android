package com.fatwabot.core.common

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class OnboardingCompletionStoreTest {
    private fun tempFile(): File = File.createTempFile("onboarding-completion", ".json").apply { deleteOnExit() }

    @Test
    fun `is completed is false until marked`() {
        val store = OnboardingCompletionStore(tempFile())
        assertFalse(store.isCompleted())
    }

    @Test
    fun `mark completed persists`() {
        val store = OnboardingCompletionStore(tempFile())
        store.markCompleted(1_700_000_000)
        assertTrue(store.isCompleted())
    }

    @Test
    fun `completion survives a fresh store instance over the same file`() {
        val file = tempFile()
        OnboardingCompletionStore(file).markCompleted(1_700_000_000)
        assertTrue(OnboardingCompletionStore(file).isCompleted())
    }
}
