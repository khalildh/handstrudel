package com.handstrudel.engine

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

/**
 * Port of iOS `Engine/HapticManager.swift`. Core Haptics transients map to
 * one-shot vibrations: intensity → amplitude, sharpness → shorter duration.
 * Devices without amplitude control get duration-only taps.
 */
class HapticManager(context: Context) {
    private val vibrator: Vibrator? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)?.defaultVibrator
    } else {
        @Suppress("DEPRECATION")
        context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
    }
    private val amplitudeControl = vibrator?.hasAmplitudeControl() == true

    /** Light tap on each beat; the downbeat is stronger. */
    fun beatPulse(isDownbeat: Boolean) = transient(if (isDownbeat) 0.6 else 0.3, if (isDownbeat) 0.5 else 0.8)

    /** Medium tap when a note is triggered. */
    fun noteTrigger() = transient(0.7, 0.4)

    /** Kept for existing callers: the chord-touch tap (iOS uses `noteTrigger`). */
    fun chordTrigger() = noteTrigger()

    /** Sharp hit for drum triggers. */
    fun drumHit() = transient(1.0, 0.8)

    fun learnPerfectHit() = transient(0.9, 0.3)
    fun learnGoodHit() = transient(0.5, 0.5)
    fun learnMiss() = transient(0.3, 1.0)

    /** Gentle UI feedback (iOS light impact). */
    fun lightTap() = transient(0.3, 0.6)

    private fun transient(intensity: Double, sharpness: Double) {
        val v = vibrator ?: return
        if (!v.hasVibrator()) return
        // Sharper transients are shorter (8–20 ms).
        val duration = (20 - sharpness * 12).toLong().coerceIn(8, 20)
        val amplitude = if (amplitudeControl) (intensity * 255).toInt().coerceIn(1, 255) else VibrationEffect.DEFAULT_AMPLITUDE
        try {
            v.vibrate(VibrationEffect.createOneShot(duration, amplitude))
        } catch (_: Throwable) {
            // Haptics are optional.
        }
    }
}
