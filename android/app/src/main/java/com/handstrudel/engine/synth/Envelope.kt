package com.handstrudel.engine.synth

enum class EnvelopeState { OFF, ATTACK, SUSTAIN, RELEASE }

class Envelope(private val sampleRate: Int = 44100) {
    var attackTime: Float = 0.01f  // seconds
    var releaseTime: Float = 0.05f // seconds
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
                val attackSamples = (attackTime * sampleRate).coerceAtLeast(1f)
                level += 1f / attackSamples
                if (level >= 1f) {
                    level = 1f
                    state = EnvelopeState.SUSTAIN
                }
            }
            EnvelopeState.SUSTAIN -> {
                level = sustainLevel
            }
            EnvelopeState.RELEASE -> {
                val releaseSamples = (releaseTime * sampleRate).coerceAtLeast(1f)
                level -= level / releaseSamples
                if (level < 0.001f) {
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
