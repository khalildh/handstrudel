package com.handstrudel.engine.synth

import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

enum class FilterType { LOW_PASS, HIGH_PASS, BAND_PASS }

class BiquadFilter(private val sampleRate: Int = 44100) {
    private var b0 = 1f; private var b1 = 0f; private var b2 = 0f
    private var a1 = 0f; private var a2 = 0f

    private var x1 = 0f; private var x2 = 0f
    private var y1 = 0f; private var y2 = 0f

    var cutoff: Float = 6000f
        set(value) { field = value.coerceIn(20f, 20000f); recalc() }

    var q: Float = 0.707f
        set(value) { field = value.coerceIn(0.1f, 30f); recalc() }

    var type: FilterType = FilterType.LOW_PASS
        set(value) { field = value; recalc() }

    init { recalc() }

    private fun recalc() {
        val w0 = 2.0 * PI * cutoff / sampleRate
        val cosw0 = cos(w0).toFloat()
        val sinw0 = sin(w0).toFloat()
        val alpha = sinw0 / (2f * q)

        when (type) {
            FilterType.LOW_PASS -> {
                val a0 = 1f + alpha
                b0 = ((1f - cosw0) / 2f) / a0
                b1 = (1f - cosw0) / a0
                b2 = b0
                a1 = (-2f * cosw0) / a0
                a2 = (1f - alpha) / a0
            }
            FilterType.HIGH_PASS -> {
                val a0 = 1f + alpha
                b0 = ((1f + cosw0) / 2f) / a0
                b1 = -(1f + cosw0) / a0
                b2 = b0
                a1 = (-2f * cosw0) / a0
                a2 = (1f - alpha) / a0
            }
            FilterType.BAND_PASS -> {
                val a0 = 1f + alpha
                b0 = (sinw0 / 2f) / a0
                b1 = 0f
                b2 = (-sinw0 / 2f) / a0
                a1 = (-2f * cosw0) / a0
                a2 = (1f - alpha) / a0
            }
        }
    }

    fun process(input: Float): Float {
        val output = b0 * input + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2 = x1; x1 = input
        y2 = y1; y1 = output
        return output
    }

    fun reset() {
        x1 = 0f; x2 = 0f; y1 = 0f; y2 = 0f
    }
}
