package com.memorycard.memory_card

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Short buzzes at a chosen strength, for scratching an answer. Flutter's own haptics have no strength,
 * so this drives the vibrator directly: a one-shot of [ms] at [amp] (1–255) where the motor can vary its
 * amplitude, and a plain one-shot elsewhere.
 */
internal object HapticsChannel {
    const val NAME = "memorycard/haptics"

    fun register(context: Context, messenger: BinaryMessenger) {
        val app = context.applicationContext
        MethodChannel(messenger, NAME).setMethodCallHandler { call, result ->
            when (call.method) {
                "pulse" -> {
                    val ms = (call.argument<Int>("ms") ?: 10).coerceIn(1, 200).toLong()
                    val amp = (call.argument<Int>("amp") ?: 128).coerceIn(1, 255)
                    pulse(app, ms, amp)
                    result.success(null)
                }
                "canVary" -> result.success(vibrator(app)?.let { Build.VERSION.SDK_INT >= 26 && it.hasAmplitudeControl() } ?: false)
                else -> result.notImplemented()
            }
        }
    }

    private fun vibrator(context: Context): Vibrator? {
        val v = if (Build.VERSION.SDK_INT >= 31) {
            (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
        return if (v?.hasVibrator() == true) v else null
    }

    private fun pulse(context: Context, ms: Long, amp: Int) {
        val v = vibrator(context) ?: return
        try {
            if (Build.VERSION.SDK_INT >= 26) {
                // Without amplitude control a weak buzz is felt as a shorter one.
                val effect = if (v.hasAmplitudeControl()) {
                    VibrationEffect.createOneShot(ms, amp)
                } else {
                    VibrationEffect.createOneShot((ms * amp / 255L).coerceAtLeast(1L), VibrationEffect.DEFAULT_AMPLITUDE)
                }
                v.vibrate(effect)
            } else {
                @Suppress("DEPRECATION")
                v.vibrate((ms * amp / 255L).coerceAtLeast(1L))
            }
        } catch (_: Exception) {
        }
    }
}
