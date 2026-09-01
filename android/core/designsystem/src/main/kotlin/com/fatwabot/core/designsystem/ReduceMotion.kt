package com.fatwabot.core.designsystem

import android.provider.Settings
import androidx.compose.animation.core.AnimationSpec
import androidx.compose.animation.core.LinearOutSlowInEasing
import androidx.compose.animation.core.snap
import androidx.compose.animation.core.tween
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner

/**
 * Mirrors iOS's `accessibilityReduceMotion`. Android has no direct equivalent
 * API; the closest system signal is the "Remove animations" accessibility
 * setting, which drives [Settings.Global.ANIMATOR_DURATION_SCALE] down to 0.
 * Provided once at the app root (see RootScaffold) so every screen can read
 * [LocalReduceMotion.current] instead of re-deriving this.
 */
val LocalReduceMotion = staticCompositionLocalOf { false }

/**
 * Re-read on every `ON_RESUME`, not once per composition.
 *
 * A bare `remember { … }` with no keys sampled the setting once and never
 * again, so toggling "Remove animations" mid-session had no effect until the
 * composable happened to leave and re-enter. iOS's environment value updates
 * live; resuming is the point at which the user can have come back from
 * Settings, so it's the correct moment to re-check.
 */
@Composable
fun rememberReduceMotion(): Boolean {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    var reduceMotion by remember { mutableStateOf(readReduceMotion(context)) }
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) reduceMotion = readReduceMotion(context)
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }
    return reduceMotion
}

private fun readReduceMotion(context: android.content.Context): Boolean =
    Settings.Global.getFloat(context.contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f

/**
 * [tween] when motion is allowed, an instant [snap] when the user has disabled
 * animations.
 *
 * Eases OUT, matching every iOS call site (`.easeOut(duration:)`). Compose's
 * `tween` defaults to `FastOutSlowInEasing` — an ease-*in*-out — so these
 * animations started slower and landed harder than their iOS counterparts.
 */
fun <T> motionAnimationSpec(reduceMotion: Boolean, durationMs: Int): AnimationSpec<T> =
    if (reduceMotion) snap() else tween(durationMs, easing = LinearOutSlowInEasing)
