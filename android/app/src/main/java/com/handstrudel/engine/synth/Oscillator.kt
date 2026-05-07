package com.handstrudel.engine.synth

import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.sin
import kotlin.random.Random

enum class WaveformType { SINE, SAWTOOTH, SQUARE, TRIANGLE }

class Oscillator(var waveform: WaveformType = WaveformType.SAWTOOTH) {
    var frequency: Float = 440f
    private var phase: Double = 0.0

    fun getSample(sampleRate: Int): Float {
        val sample = when (waveform) {
            WaveformType.SINE -> sin(2.0 * PI * phase).toFloat()
            WaveformType.SAWTOOTH -> (2.0 * (phase % 1.0) - 1.0).toFloat()
            WaveformType.SQUARE -> if ((phase % 1.0) < 0.5) 1f else -1f
            WaveformType.TRIANGLE -> (4.0 * abs((phase % 1.0) - 0.5) - 1.0).toFloat()
        }
        phase += frequency.toDouble() / sampleRate
        if (phase > 1000.0) phase -= 1000.0 // prevent overflow
        return sample
    }

    fun setFrequencyFromMidi(midi: Int) {
        frequency = (440.0 * Math.pow(2.0, (midi - 69).toDouble() / 12.0)).toFloat()
    }

    fun reset() {
        phase = 0.0
    }

    companion object {
        fun whiteNoise(): Float = Random.nextFloat() * 2f - 1f

        fun parseWaveform(name: String): WaveformType = when (name) {
            "sine" -> WaveformType.SINE
            "square" -> WaveformType.SQUARE
            "triangle" -> WaveformType.TRIANGLE
            else -> WaveformType.SAWTOOTH
        }
    }
}
