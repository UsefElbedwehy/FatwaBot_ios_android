package com.fatwabot.app.navigation

import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.hilt.navigation.compose.hiltViewModel
import com.fatwabot.core.common.ContentFocus
import com.fatwabot.core.common.DeepLink
import com.fatwabot.core.common.OnboardingCompletionStore
import com.fatwabot.core.designsystem.LocalReduceMotion
import com.fatwabot.core.designsystem.rememberReduceMotion
import com.fatwabot.feature.onboarding.OnboardingScreen
import dagger.hilt.EntryPoint
import dagger.hilt.InstallIn
import dagger.hilt.android.EntryPointAccessors
import dagger.hilt.components.SingletonComponent

@EntryPoint
@InstallIn(SingletonComponent::class)
private interface OnboardingCompletionStoreEntryPoint {
    fun onboardingCompletionStore(): OnboardingCompletionStore
}

/** Top-level gate: shows the value-first onboarding flow
 * (docs/features/onboarding.md) once per install, then RootScaffold forever
 * after — mirror of iOS AppRootView. */
@Composable
fun AppRoot(
    deepLink: DeepLink? = null,
    contentFocus: ContentFocus? = null,
    onDeepLinkHandled: () -> Unit = {},
) {
    val context = LocalContext.current
    var isOnboardingCompleted by remember {
        val store = EntryPointAccessors.fromApplication(
            context.applicationContext, OnboardingCompletionStoreEntryPoint::class.java,
        ).onboardingCompletionStore()
        mutableStateOf(store.isCompleted())
    }

    CompositionLocalProvider(LocalReduceMotion provides rememberReduceMotion()) {
        if (isOnboardingCompleted) {
            RootScaffold(deepLink = deepLink, contentFocus = contentFocus, onDeepLinkHandled = onDeepLinkHandled)
        } else {
            OnboardingScreen(viewModel = hiltViewModel(), onFinished = { isOnboardingCompleted = true })
        }
    }
}
