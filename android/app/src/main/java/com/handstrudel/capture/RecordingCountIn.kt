package com.handstrudel.capture

import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.PI
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sin

/**
 * iOS `RecordingCountIn` (`App/ContentView.swift`). With a play-along source BPM
 * in 20…400 it counts 4 beats with a click (1480 Hz downbeat, 990 Hz others);
 * otherwise 3 × 1 s, silent. At half speed each beat is twice as long, matching
 * the half-tempo performance that follows.
 */
class RecordingCountIn(sourceBPM: Double?, halfSpeed: Boolean) {
    val steps: Int
    val secondsPerStep: Double
    val usesBeats: Boolean get() = steps == 4

    init {
        if (sourceBPM != null && sourceBPM in 20.0..400.0) {
            steps = 4
            secondsPerStep = 60.0 / sourceBPM * (if (halfSpeed) 2.0 else 1.0)
        } else {
            steps = 3
            secondsPerStep = 1.0
        }
    }

    /** Sample index of each click onset in [clickSamples]. */
    fun clickOnsets(): List<Int> =
        (0 until steps).map { beat -> (beat * secondsPerStep * SAMPLE_RATE).roundToInt() }

    /**
     * Mono 16-bit PCM at [SAMPLE_RATE] with all clicks in one buffer, so every
     * click shares one audio clock. Null when counting seconds (no click).
     */
    fun clickSamples(): ShortArray? {
        if (!usesBeats) return null
        val sampleCount = (steps * secondsPerStep * SAMPLE_RATE).roundToInt()
        val clickLength = SAMPLE_RATE / 25
        val samples = ShortArray(sampleCount)
        clickOnsets().forEachIndexed { beat, onset ->
            val frequency = if (beat == 0) 1_480.0 else 990.0
            for (sample in 0 until clickLength) {
                val index = onset + sample
                if (index >= sampleCount) break
                val phase = sample.toDouble() / clickLength
                val envelope = min(1.0, phase * 25) * (1 - phase) * (1 - phase)
                val wave = sin(2 * PI * frequency * sample / SAMPLE_RATE)
                samples[index] = (wave * envelope * 13_000).toInt().toShort()
            }
        }
        return samples
    }

    /** The click track as a WAV file (iOS `clickTrack()`); null without beats. */
    fun clickTrack(): ByteArray? {
        val samples = clickSamples() ?: return null
        val dataSize = samples.size * 2
        val buffer = ByteBuffer.allocate(44 + dataSize).order(ByteOrder.LITTLE_ENDIAN)
        buffer.put("RIFF".toByteArray()).putInt(36 + dataSize).put("WAVEfmt ".toByteArray())
        buffer.putInt(16).putShort(1).putShort(1) // PCM, mono
        buffer.putInt(SAMPLE_RATE).putInt(SAMPLE_RATE * 2).putShort(2).putShort(16)
        buffer.put("data".toByteArray()).putInt(dataSize)
        samples.forEach { buffer.putShort(it) }
        return buffer.array()
    }

    companion object {
        const val SAMPLE_RATE = 22_050
    }
}

/** iOS `BackingTrackVolume`. */
object BackingTrackVolume {
    const val DEFAULT_VALUE = 0.55
    fun clamped(value: Double): Double = if (value.isFinite()) value.coerceIn(0.0, 1.0) else DEFAULT_VALUE
}
