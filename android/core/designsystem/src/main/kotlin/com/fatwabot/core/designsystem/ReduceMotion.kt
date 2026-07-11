package com.fatwabot.core.designsystem

import android.provider.Settings
import androidx.compose.animation.core.AnimationSpec
import androidx.compose.animation.core.snap
import androidx.compose.animation.core.tween
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.platform.LocalContext

/**
 * Mirrors iOS's `accessibilityReduceMotion`. Android has no direct equivalent
 * API; the closest system signal is the "Remove animations" accessibility
 * setting, which drives [Settings.Global.ANIMATOR_DURATION_SCALE] down to 0.
 * Provided once at the app root (see RootScaffold) so every screen can read
 * [LocalReduceMotion.current] instead of re-deriving this.
 */
val LocalReduceMotion = staticCompositionLocalOf { false }

@Composable
fun rememberReduceMotion(): Boolean {
    val context = LocalContext.current
    return remember {
        Settings.Global.getFloat(context.contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f
    }
}

/** [tween] when motion is allowed, an instant [snap] when the user has disabled animations. */
fun <T> motionAnimationSpec(reduceMotion: Boolean, durationMs: Int): AnimationSpec<T> =
    if (reduceMotion) snap() else tween(durationMs)
