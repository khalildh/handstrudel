package com.handstrudel.engine

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

/// Thin wrapper around the platform vibrator that picks a sane API path for
/// each Android version and fires short ticks for note + chord triggers.
/// Mirrors iOS's `HapticManager.noteTrigger()` shape so the engine can call
/// the same method in both ports.
class HapticManager(context: Context) {
    private val vibrator: Vibrator? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        @Suppress("DEPRECATION")
        (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)?.defaultVibrator
    } else {
        @Suppress("DEPRECATION")
        context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
    }

    /// A brief tick for "I started a note". Light enough to layer with
    /// every chord-note onset in a strum without buzzing the whole device.
    fun noteTrigger() = oneShot(durationMs = 12L, amplitude = 60)

    /// A slightly heavier tap for "I started a chord". One-per-strum.
    fun chordTrigger() = oneShot(durationMs = 18L, amplitude = 90)

    private fun oneShot(durationMs: Long, amplitude: Int) {
        val v = vibrator ?: return
        if (!v.hasVibrator()) return
        try {
            v.vibrate(VibrationEffect.createOneShot(durationMs, amplitude.coerceIn(1, 255)))
        } catch (_: Throwable) {
            // Some OEMs throw on certain amplitude values — silently skip.
        }
    }
}
