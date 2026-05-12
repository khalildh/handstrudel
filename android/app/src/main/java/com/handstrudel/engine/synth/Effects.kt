package com.handstrudel.engine.synth

import kotlin.math.*

class DelayEffect(private val sampleRate: Int = 44100, maxDelayMs: Int = 600) {
    private val buffer = FloatArray((sampleRate * maxDelayMs / 1000.0).toInt())
    private var writePos = 0
    var delayTime: Float = 0.12f // seconds
    var feedback: Float = 0.3f
    var mix: Float = 0.3f

    fun process(input: Float): Float {
        val delaySamples = (delayTime * sampleRate).toInt().coerceIn(1, buffer.size - 1)
        val readPos = (writePos - delaySamples + buffer.size) % buffer.size
        val delayed = buffer[readPos]
        buffer[writePos] = input + delayed * feedback
        writePos = (writePos + 1) % buffer.size
        return input * (1f - mix) + delayed * mix
    }
}

class BitCrush {
    var bits: Float = 16f // 1-16

    fun process(input: Float): Float {
        if (bits >= 15.5f) return input
        val levels = 2f.pow(bits.coerceIn(1f, 16f))
        return floor(input * levels) / levels
    }
}

class WaveShaper {
    var amount: Float = 0f // 0-0.9

    fun process(input: Float): Float {
        if (amount < 0.01f) return input
        val k = amount * 10f
        return tanh(k * input.toDouble()).toFloat()
    }
}

class Panner {
    var pan: Float = 0.5f // 0=left, 1=right

    fun process(input: Float): Pair<Float, Float> {
        val angle = pan * PI.toFloat() / 2f
        return Pair(input * cos(angle), input * sin(angle))
    }
}

class SimpleReverb(private val sampleRate: Int = 44100) {
    var mix: Float = 0.2f

    // 4 comb filters with different delay times
    private val combDelays = intArrayOf(
        (0.0297 * sampleRate).toInt(),
        (0.0371 * sampleRate).toInt(),
        (0.0411 * sampleRate).toInt(),
        (0.0437 * sampleRate).toInt()
    )
    private val combBuffers = Array(4) { FloatArray(combDelays[it]) }
    private val combPositions = IntArray(4)
    private val combFeedback = 0.85f

    // 2 allpass filters
    private val allpassDelays = intArrayOf(
        (0.005 * sampleRate).toInt(),
        (0.0017 * sampleRate).toInt()
    )
    private val allpassBuffers = Array(2) { FloatArray(allpassDelays[it]) }
    private val allpassPositions = IntArray(2)
    private val allpassGain = 0.5f

    fun process(input: Float): Float {
        if (mix < 0.01f) return input

        // Sum of comb filters
        var combSum = 0f
        for (i in 0..3) {
            val buf = combBuffers[i]
            val pos = combPositions[i]
            val delayed = buf[pos]
            buf[pos] = input + delayed * combFeedback
            combPositions[i] = (pos + 1) % buf.size
            combSum += delayed
        }
        combSum /= 4f

        // Series allpass filters
        var out = combSum
        for (i in 0..1) {
            val buf = allpassBuffers[i]
            val pos = allpassPositions[i]
            val delayed = buf[pos]
            buf[pos] = out + delayed * allpassGain
            allpassPositions[i] = (pos + 1) % buf.size
            out = delayed - out * allpassGain
        }

        return input * (1f - mix) + out * mix
    }
}

private fun Float.pow(exp: Float): Float = this.toDouble().pow(exp.toDouble()).toFloat()
