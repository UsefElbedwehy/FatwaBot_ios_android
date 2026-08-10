package com.fatwabot.feature.onboarding

import android.Manifest
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccountCircle
import androidx.compose.material.icons.filled.Book
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.fatwabot.core.designsystem.ArchIconBadge
import com.fatwabot.core.network.AccountProvider
import com.fatwabot.feature.onboarding.R
import kotlinx.coroutines.launch

/** Value-first onboarding flow — mirror of iOS OnboardingScreen
 * (docs/features/onboarding.md). Runtime-permission dialogs are launched
 * here (Composable scope) since Android requires an Activity result
 * contract for that; the ViewModel only tracks step + persists completion.
 * [onFinished] is the composition root's signal to swap in RootScaffold. */
@Composable
fun OnboardingScreen(viewModel: OnboardingViewModel = hiltViewModel(), onFinished: () -> Unit = {}) {
    val step by viewModel.step.collectAsStateWithLifecycle()

    val locationPermissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { viewModel.advance() }

    val notificationPermissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { viewModel.advance() }

    Box(modifier = Modifier.fillMaxSize()) {
        when (step) {
            OnboardingStep.WELCOME -> WelcomeStep(onContinue = viewModel::advance)
            OnboardingStep.HIGHLIGHTS -> HighlightsStep(onContinue = viewModel::advance)
            OnboardingStep.LOCATION_PRIMING -> PrimingStep(
                icon = Icons.Filled.Schedule,
                title = stringResource(R.string.onboarding_location_title),
                body = stringResource(R.string.onboarding_location_body),
                onAllow = { locationPermissionLauncher.launch(Manifest.permission.ACCESS_COARSE_LOCATION) },
                onSkip = viewModel::skip,
            )
            OnboardingStep.NOTIFICATION_PRIMING -> PrimingStep(
                icon = Icons.Filled.Book,
                title = stringResource(R.string.onboarding_notification_title),
                body = stringResource(R.string.onboarding_notification_body),
                onAllow = {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                    } else {
                        viewModel.advance()
                    }
                },
                onSkip = viewModel::advance,
            )
            OnboardingStep.SIGN_IN -> SignInStep(viewModel = viewModel, onFinished = onFinished)
        }
    }
}

/** Optional account step — always escapable via "Continue as guest". */
@Composable
private fun SignInStep(viewModel: OnboardingViewModel, onFinished: () -> Unit) {
    val isSigningIn by viewModel.isSigningIn.collectAsStateWithLifecycle()
    val failed by viewModel.signInFailed.collectAsStateWithLifecycle()
    val scope = rememberCoroutineScope()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Icon(
            Icons.Filled.AccountCircle,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.primary,
            modifier = Modifier.size(64.dp),
        )
        Spacer(modifier = Modifier.height(24.dp))
        Text(
            stringResource(R.string.onboarding_sign_in_title),
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center,
        )
        Spacer(modifier = Modifier.height(12.dp))
        Text(
            stringResource(R.string.onboarding_sign_in_body),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
        )
        Spacer(modifier = Modifier.height(28.dp))

        if (failed) {
            Text(
                stringResource(R.string.onboarding_sign_in_failed),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.error,
                textAlign = TextAlign.Center,
            )
            Spacer(modifier = Modifier.height(12.dp))
        }

        viewModel.signInOptions.forEach { provider ->
            Button(
                onClick = {
                    scope.launch { if (viewModel.signIn(provider)) onFinished() }
                },
                enabled = !isSigningIn,
                modifier = Modifier.fillMaxWidth(),
                contentPadding = PaddingValues(vertical = 16.dp),
            ) {
                Text(
                    when (provider) {
                        AccountProvider.APPLE -> stringResource(R.string.onboarding_sign_in_apple)
                        else -> stringResource(R.string.onboarding_sign_in_google)
                    },
                    fontWeight = FontWeight.SemiBold,
                )
            }
            Spacer(modifier = Modifier.height(10.dp))
        }

        TextButton(
            onClick = {
                viewModel.continueAsGuest()
                onFinished()
            },
            enabled = !isSigningIn,
            modifier = Modifier.fillMaxWidth(),
        ) { Text(stringResource(R.string.onboarding_continue_as_guest)) }
    }
}

@Composable
private fun WelcomeStep(onContinue: () -> Unit) {
    Column(
        modifier = Modifier.fillMaxSize().padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        ArchIconBadge(icon = Icons.Filled.LocalFireDepartment, size = 88.dp)
        Spacer(modifier = Modifier.height(24.dp))
        Text(
            stringResource(R.string.onboarding_welcome_title),
            style = MaterialTheme.typography.headlineMedium,
            modifier = Modifier.semantics { heading() },
        )
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            stringResource(R.string.onboarding_welcome_body),
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(modifier = Modifier.height(32.dp))
        Button(
            onClick = onContinue,
            modifier = Modifier.fillMaxWidth(),
            contentPadding = PaddingValues(vertical = 16.dp),
        ) { Text(stringResource(R.string.onboarding_get_started)) }
    }
}

private data class Highlight(val icon: ImageVector, val title: String)

@Composable
private fun HighlightsStep(onContinue: () -> Unit) {
    val prayerTitle = stringResource(R.string.onboarding_highlight_prayer)
    val azkarTitle = stringResource(R.string.onboarding_highlight_azkar)
    val streakTitle = stringResource(R.string.onboarding_highlight_streak)
    val highlights = remember(prayerTitle, azkarTitle, streakTitle) {
        listOf(
            Highlight(Icons.Filled.Schedule, prayerTitle),
            Highlight(Icons.Filled.Book, azkarTitle),
            Highlight(Icons.Filled.LocalFireDepartment, streakTitle),
        )
    }
    val pagerState = rememberPagerState { highlights.size }

    Column(modifier = Modifier.fillMaxSize().padding(24.dp)) {
        Text(
            stringResource(R.string.onboarding_highlights_title),
            style = MaterialTheme.typography.headlineSmall,
            modifier = Modifier.fillMaxWidth().semantics { heading() },
            textAlign = TextAlign.Center,
        )
        Spacer(modifier = Modifier.height(24.dp))
        HorizontalPager(state = pagerState, modifier = Modifier.weight(1f)) { page ->
            val highlight = highlights[page]
            Column(
                modifier = Modifier.fillMaxSize().padding(32.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center,
            ) {
                ArchIconBadge(icon = highlight.icon, size = 72.dp)
                Spacer(modifier = Modifier.height(16.dp))
                Text(
                    highlight.title,
                    style = MaterialTheme.typography.titleMedium,
                    textAlign = TextAlign.Center,
                )
            }
        }
        Button(
            onClick = onContinue,
            modifier = Modifier.fillMaxWidth(),
            contentPadding = PaddingValues(vertical = 16.dp),
        ) { Text(stringResource(R.string.onboarding_continue)) }
    }
}

@Composable
private fun PrimingStep(
    icon: ImageVector,
    title: String,
    body: String,
    onAllow: () -> Unit,
    onSkip: () -> Unit,
) {
    Column(
        modifier = Modifier.fillMaxSize().padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        ArchIconBadge(icon = icon, size = 80.dp)
        Spacer(modifier = Modifier.height(24.dp))
        Text(
            title,
            style = MaterialTheme.typography.headlineSmall,
            textAlign = TextAlign.Center,
            modifier = Modifier.semantics { heading() },
        )
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            body,
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
        )
        Spacer(modifier = Modifier.height(32.dp))
        Button(
            onClick = onAllow,
            modifier = Modifier.fillMaxWidth(),
            contentPadding = PaddingValues(vertical = 16.dp),
        ) { Text(stringResource(R.string.onboarding_allow)) }
        TextButton(
            onClick = onSkip,
            contentPadding = ButtonDefaults.TextButtonContentPadding,
        ) { Text(stringResource(R.string.onboarding_not_now)) }
    }
}
