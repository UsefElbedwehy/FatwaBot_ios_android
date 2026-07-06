package com.fatwabot.app.tasbeeh

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.core.content.getSystemService
import com.fatwabot.core.common.HapticsProviding

/** Vibrator-based haptics — mirror of iOS SystemHaptics (light tick / success pattern). */
class SystemHaptics(private val context: Context) : HapticsProviding {
    private val vibrator: Vibrator? by lazy {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            context.getSystemService<VibratorManager>()?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService<Vibrator>()
        }
    }

    override fun tick() {
        vibrate(VibrationEffect.createOneShot(15, 60))
    }

    override fun targetReached() {
        vibrate(
            VibrationEffect.createWaveform(longArrayOf(0, 40, 40, 40), intArrayOf(0, 180, 0, 180), -1),
        )
    }

    private fun vibrate(effect: VibrationEffect) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator?.vibrate(effect)
        }
    }
}
