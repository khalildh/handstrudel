package com.handstrudel.engine.synth

import kotlin.math.exp
import kotlin.math.pow
import kotlin.random.Random

class DrumSynth(private val sampleRate: Int = 44100) {
    private val activeHits = mutableListOf<DrumHitVoice>()
    var intensity: Float = 0.5f  // 0=soft, 1=loud
    var complexity: Float = 0.5f // 0=simple, 1=complex

    fun triggerHit(type: String) {
        val vol = 0.3f + intensity * 1.2f
        val decay = 0.8f + complexity * 1.5f
        val pitchVar = 1f + (complexity - 0.5f) * 0.3f

        val voice = when (type) {
            "kick" -> createKick(vol, decay, pitchVar)
            "snare" -> createSnare(vol, decay, pitchVar)
            "hihat" -> createHiHat(vol, decay)
            "crash" -> createCrash(vol, decay)
            "ride" -> createRide(vol, decay)
            "tom" -> createTom(vol, decay, pitchVar)
            else -> return
        }
        synchronized(activeHits) { activeHits.add(voice) }
    }

    fun getSample(): Float {
        var mix = 0f
        synchronized(activeHits) {
            val iter = activeHits.iterator()
            while (iter.hasNext()) {
                val voice = iter.next()
                mix += voice.getSample(sampleRate)
                if (voice.isDone()) iter.remove()
            }
        }
        return mix.coerceIn(-1f, 1f)
    }

    private fun createKick(vol: Float, decay: Float, pitchVar: Float): DrumHitVoice {
        val durationSamples = (0.5f * decay * sampleRate).toInt()
        return DrumHitVoice(durationSamples) { pos ->
            val t = pos.toFloat() / sampleRate
            val freq = 150f * pitchVar * exp(-t / (0.15f * decay) * 5f).coerceAtLeast(0.2f)
            val osc = kotlin.math.sin(2.0 * Math.PI * freq * t).toFloat()
            val env = exp(-t / (0.3f * decay) * 5f)
            osc * vol * env
        }
    }

    private fun createSnare(vol: Float, decay: Float, pitchVar: Float): DrumHitVoice {
        val dur = 0.12f * decay
        val durationSamples = ((dur + 0.15f * decay) * sampleRate).toInt()
        val lpf = BiquadFilter(sampleRate).apply { cutoff = 4000f + intensity * 4000f; type = FilterType.LOW_PASS }
        val hpf = BiquadFilter(sampleRate).apply { cutoff = 800f + (1f - complexity) * 400f; type = FilterType.HIGH_PASS }
        return DrumHitVoice(durationSamples) { pos ->
            val t = pos.toFloat() / sampleRate
            // Noise component
            val noise = Oscillator.whiteNoise()
            val filtered = lpf.process(hpf.process(noise))
            val noiseEnv = exp(-t / dur * 5f)
            val noisePart = filtered * vol * 0.7f * noiseEnv
            // Tone component
            val tone = kotlin.math.sin(2.0 * Math.PI * 160.0 * pitchVar * t).toFloat()
            val toneEnv = exp(-t / (0.08f * decay) * 5f)
            val tonePart = tone * vol * 0.4f * toneEnv
            noisePart + tonePart
        }
    }

    private fun createHiHat(vol: Float, decay: Float): DrumHitVoice {
        val dur = (0.02f + complexity * 0.08f) * decay
        val durationSamples = (dur * sampleRate).toInt() + 100
        val hpf = BiquadFilter(sampleRate).apply {
            cutoff = 6000f + (1f - complexity) * 4000f; type = FilterType.HIGH_PASS
        }
        return DrumHitVoice(durationSamples) { pos ->
            val t = pos.toFloat() / sampleRate
            val noise = Oscillator.whiteNoise()
            val env = exp(-t / dur * 5f)
            hpf.process(noise) * vol * 0.35f * env
        }
    }

    private fun createCrash(vol: Float, decay: Float): DrumHitVoice {
        val dur = (0.15f + complexity * 0.3f) * decay
        val durationSamples = (dur * sampleRate).toInt() + 100
        val hpf = BiquadFilter(sampleRate).apply { cutoff = 4000f; type = FilterType.HIGH_PASS }
        return DrumHitVoice(durationSamples) { pos ->
            val t = pos.toFloat() / sampleRate
            val noise = Oscillator.whiteNoise()
            val env = exp(-t / dur * 5f)
            hpf.process(noise) * vol * 0.5f * env
        }
    }

    private fun createRide(vol: Float, decay: Float): DrumHitVoice {
        val dur = (0.1f + complexity * 0.15f) * decay
        val durationSamples = (dur * sampleRate).toInt() + 100
        val bpf = BiquadFilter(sampleRate).apply {
            cutoff = 5000f + complexity * 2000f; q = 1f + complexity * 3f; type = FilterType.BAND_PASS
        }
        return DrumHitVoice(durationSamples) { pos ->
            val t = pos.toFloat() / sampleRate
            val noise = Oscillator.whiteNoise()
            val env = exp(-t / dur * 5f)
            bpf.process(noise) * vol * 0.35f * env
        }
    }

    private fun createTom(vol: Float, decay: Float, pitchVar: Float): DrumHitVoice {
        val durationSamples = (0.4f * decay * sampleRate).toInt()
        return DrumHitVoice(durationSamples) { pos ->
            val t = pos.toFloat() / sampleRate
            val freq = 100f * pitchVar * exp(-t / (0.15f * decay) * 5f).coerceAtLeast(0.5f)
            val osc = kotlin.math.sin(2.0 * Math.PI * freq * t).toFloat()
            val env = exp(-t / (0.2f * decay) * 5f)
            osc * vol * 0.9f * env
        }
    }

    private fun exp(x: Float): Float = kotlin.math.exp(x.toDouble()).toFloat()
}

class DrumHitVoice(
    private val durationSamples: Int,
    private val generator: (Int) -> Float
) {
    private var position = 0

    fun getSample(sampleRate: Int): Float {
        if (position >= durationSamples) return 0f
        return generator(position++)
    }

    fun isDone(): Boolean = position >= durationSamples
}
