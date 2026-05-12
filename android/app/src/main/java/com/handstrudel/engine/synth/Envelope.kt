package com.handstrudel.engine.synth

enum class EnvelopeState { OFF, ATTACK, SUSTAIN, RELEASE }

class Envelope(private val sampleRate: Int = 44100) {
    var attackTime: Float = 0.01f
    var releaseTime: Float = 0.08f
    var sustainLevel: Float = 1.0f

    private var state = EnvelopeState.OFF
    private var level = 0f
    val isActive get() = state != EnvelopeState.OFF

    fun noteOn() {
        state = EnvelopeState.ATTACK
    }

    fun noteOff() {
        if (state != EnvelopeState.OFF) {
            state = EnvelopeState.RELEASE
        }
    }

    fun getSample(): Float {
        when (state) {
            EnvelopeState.OFF -> return 0f
            EnvelopeState.ATTACK -> {
                val rate = 1f / (attackTime * sampleRate).coerceAtLeast(1f)
                level += rate
                if (level >= sustainLevel) {
                    level = sustainLevel
                    state = EnvelopeState.SUSTAIN
                }
            }
            EnvelopeState.SUSTAIN -> {
                level = sustainLevel
            }
            EnvelopeState.RELEASE -> {
                // Exponential decay for smooth release
                val rate = 1f / (releaseTime * sampleRate).coerceAtLeast(1f)
                level *= (1f - rate * 3f) // exponential-ish decay
                if (level < 0.0005f) {
                    level = 0f
                    state = EnvelopeState.OFF
                }
            }
        }
        return level
    }

    fun reset() {
        state = EnvelopeState.OFF
        level = 0f
    }
}
