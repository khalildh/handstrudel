package com.handstrudel.engine.synth

class StepSequencer(private val sampleRate: Int = 44100) {
    private var steps: List<Boolean> = listOf(true, false, true, false, true, false, true, false)
    var bpm: Float = 120f
    private var position: Long = 0
    private var lastStepIndex = -1
    var onStep: ((Boolean) -> Unit)? = null

    fun setPattern(pattern: String) {
        steps = parsePattern(pattern)
        position = 0
        lastStepIndex = -1
    }

    fun advance() {
        if (steps.isEmpty()) return
        val samplesPerBeat = (sampleRate * 60.0 / bpm).toLong()
        val samplesPerStep = samplesPerBeat / 2 // 8 steps per bar = 2 steps per beat
        val stepIndex = ((position / samplesPerStep) % steps.size).toInt()

        if (stepIndex != lastStepIndex) {
            lastStepIndex = stepIndex
            onStep?.invoke(steps[stepIndex])
        }
        position++
    }

    fun reset() {
        position = 0
        lastStepIndex = -1
    }

    companion object {
        fun parsePattern(pattern: String): List<Boolean> {
            val result = mutableListOf<Boolean>()
            var i = 0
            val trimmed = pattern.trim()
            while (i < trimmed.length) {
                when {
                    trimmed[i] == 'x' -> { result.add(true); i++ }
                    trimmed[i] == '~' -> { result.add(false); i++ }
                    trimmed[i] == '[' -> {
                        // Find matching ]
                        val end = trimmed.indexOf(']', i)
                        if (end == -1) { i++; continue }
                        val inner = trimmed.substring(i + 1, end).trim()
                        val subSteps = inner.split("\\s+".toRegex())
                        for (sub in subSteps) {
                            result.add(sub == "x")
                        }
                        i = end + 1
                    }
                    trimmed[i] == ' ' -> i++
                    else -> i++
                }
            }
            return if (result.isEmpty()) listOf(false) else result
        }
    }
}
