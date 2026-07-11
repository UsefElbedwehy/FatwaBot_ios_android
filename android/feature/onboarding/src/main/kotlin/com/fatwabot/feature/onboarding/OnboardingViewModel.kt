package com.fatwabot.feature.onboarding

import androidx.lifecycle.ViewModel
import com.fatwabot.core.common.OnboardingCompletionStore
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/** The 4 screens of the value-first onboarding flow (docs/features/onboarding.md). */
enum class OnboardingStep {
    WELCOME, HIGHLIGHTS, LOCATION_PRIMING, NOTIFICATION_PRIMING
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
) : ViewModel() {
    private val _step = MutableStateFlow(OnboardingStep.WELCOME)
    val step: StateFlow<OnboardingStep> = _step.asStateFlow()

    private var finished = false

    /** Sequences forward; finishes onboarding once past the last step. */
    fun advance() {
        val next = OnboardingStep.entries.getOrNull(_step.value.ordinal + 1)
        if (next == null) {
            finish()
        } else {
            _step.value = next
        }
    }

    /** "Not now" / "Skip" — never triggers a permission request, just sequences forward. */
    fun skip() = advance()

    fun finish() {
        if (finished) return
        finished = true
        completionStore.markCompleted(System.currentTimeMillis() / 1000)
    }
}
