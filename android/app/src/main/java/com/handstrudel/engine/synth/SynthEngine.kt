package com.handstrudel.engine.synth

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.os.Process
import android.util.Log

class SynthEngine(private val sampleRate: Int = 44100) {
    private var audioTrack: AudioTrack? = null
    private var audioThread: Thread? = null
    @Volatile private var running = false

    // Synth voices
    private val melodicOsc = Oscillator()
    private val melodicEnvelope = Envelope(sampleRate)
    private val noteVoices = mutableMapOf<String, NoteVoice>()

    // Effects
    private val lpf = BiquadFilter(sampleRate).apply { type = FilterType.LOW_PASS; cutoff = 6000f }
    private val hpf = BiquadFilter(sampleRate).apply { type = FilterType.HIGH_PASS; cutoff = 20f }
    private val delay = DelayEffect(sampleRate)
    private val crush = BitCrush()
    private val shaper = WaveShaper()
    private val panner = Panner()
    private val reverb = SimpleReverb(sampleRate)

    // Drums
    val drumSynth = DrumSynth(sampleRate)

    // Step sequencer for melodic patterns
    private val melodicSequencer = StepSequencer(sampleRate)
    private var melodicPlaying = false

    // Parameters (updated from main thread via volatile)
    @Volatile var melodicMidi: Int = 60
    @Volatile var melodicWaveform: String = "sawtooth"
    @Volatile var gain: Float = 0.55f
    @Volatile var lpfCutoff: Float = 3000f
    @Volatile var hpfCutoff: Float = 20f
    @Volatile var reverbMix: Float = 0.2f
    @Volatile var delayTime: Float = 0.12f
    @Volatile var panValue: Float = 0.5f
    @Volatile var crushBits: Float = 16f
    @Volatile var shapeAmount: Float = 0f
    @Volatile var attackTime: Float = 0.01f
    @Volatile var releaseTime: Float = 0.1f
    @Volatile var bpm: Float = 120f
    @Volatile var structPattern: String = "x ~ x ~ x ~ x ~"

    // Beat tracking
    @Volatile var currentBeat: Int = 0
    var onBeat: ((Int) -> Unit)? = null
    private var sampleCount: Long = 0

    fun start() {
        if (running) return
        running = true

        val bufferSize = AudioTrack.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_OUT_STEREO,
            AudioFormat.ENCODING_PCM_16BIT
        )

        audioTrack = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build()
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setSampleRate(sampleRate)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_STEREO)
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .build()
            )
            .setBufferSizeInBytes(bufferSize * 2)
            .setTransferMode(AudioTrack.MODE_STREAM)
            .build()

        audioTrack?.play()

        melodicSequencer.setPattern(structPattern)
        melodicSequencer.onStep = { isHit ->
            if (isHit) {
                melodicEnvelope.attackTime = attackTime
                melodicEnvelope.noteOn()
                melodicPlaying = true
            } else {
                melodicEnvelope.releaseTime = releaseTime
                melodicEnvelope.noteOff()
            }
        }

        audioThread = Thread({
            Process.setThreadPriority(Process.THREAD_PRIORITY_URGENT_AUDIO)
            val chunkSize = 512
            val buffer = ShortArray(chunkSize * 2) // stereo

            while (running) {
                for (i in 0 until chunkSize) {
                    val sample = generateSample()
                    sampleCount++

                    // Beat tracking
                    val samplesPerBeat = (sampleRate * 60.0 / bpm).toLong()
                    val beat = ((sampleCount / (samplesPerBeat / 2)) % 4).toInt()
                    if (beat != currentBeat) {
                        currentBeat = beat
                        onBeat?.invoke(beat)
                    }

                    // Apply master effects
                    val (left, right) = masterProcess(sample)
                    buffer[i * 2] = (left * 32767).toInt().coerceIn(-32768, 32767).toShort()
                    buffer[i * 2 + 1] = (right * 32767).toInt().coerceIn(-32768, 32767).toShort()
                }

                audioTrack?.write(buffer, 0, buffer.size)
            }
        }, "SynthAudio").apply {
            priority = Thread.MAX_PRIORITY
        }
        audioThread?.start()

        Log.d("SynthEngine", "Audio engine started")
    }

    fun stop() {
        running = false
        audioThread?.join(1000)
        audioTrack?.stop()
        audioTrack?.release()
        audioTrack = null
        Log.d("SynthEngine", "Audio engine stopped")
    }

    private fun generateSample(): Float {
        var sample = 0f

        // Melodic voice (step sequenced)
        melodicSequencer.bpm = bpm
        melodicSequencer.advance()

        if (melodicEnvelope.isActive) {
            melodicOsc.waveform = Oscillator.parseWaveform(melodicWaveform)
            melodicOsc.setFrequencyFromMidi(melodicMidi)
            val oscSample = melodicOsc.getSample(sampleRate)
            sample += oscSample * melodicEnvelope.getSample()
        }

        // Note voices (grid mode)
        synchronized(noteVoices) {
            val iter = noteVoices.entries.iterator()
            while (iter.hasNext()) {
                val (_, voice) = iter.next()
                sample += voice.getSample(sampleRate)
                if (!voice.isActive()) iter.remove()
            }
        }

        // Drum hits
        sample += drumSynth.getSample()

        return sample
    }

    private fun masterProcess(input: Float): Pair<Float, Float> {
        // Update effect params
        lpf.cutoff = lpfCutoff
        hpf.cutoff = hpfCutoff
        delay.delayTime = delayTime
        delay.mix = delayTime.coerceIn(0f, 0.55f) / 0.55f * 0.4f
        crush.bits = crushBits
        shaper.amount = shapeAmount
        panner.pan = panValue
        reverb.mix = reverbMix

        var s = input

        // Effects chain
        s = lpf.process(s)
        s = hpf.process(s)
        s = crush.process(s)
        s = shaper.process(s)
        s = delay.process(s)
        s = reverb.process(s)
        s *= gain

        val (left, right) = panner.process(s)
        return Pair(left, right)
    }

    // Grid mode note control
    fun noteOn(hand: String, midi: Int, waveform: String, velocity: Float) {
        val voice = NoteVoice(sampleRate, midi, waveform, velocity)
        synchronized(noteVoices) {
            noteVoices[hand]?.release()
            noteVoices[hand] = voice
        }
    }

    fun noteOff(hand: String) {
        synchronized(noteVoices) {
            noteVoices[hand]?.release()
        }
    }

    fun noteSlide(hand: String, midi: Int) {
        synchronized(noteVoices) {
            noteVoices[hand]?.setMidi(midi)
        }
    }

    fun playHit(type: String) {
        drumSynth.triggerHit(type)
    }

    fun updateStructPattern(pattern: String) {
        if (pattern != structPattern) {
            structPattern = pattern
            melodicSequencer.setPattern(pattern)
        }
    }
}

private class NoteVoice(
    sampleRate: Int,
    midi: Int,
    waveform: String,
    velocity: Float
) {
    private val osc = Oscillator(Oscillator.parseWaveform(waveform))
    private val env = Envelope(sampleRate).apply {
        attackTime = 0.01f
        releaseTime = 0.05f
    }
    private val lpf = BiquadFilter(sampleRate).apply {
        type = FilterType.LOW_PASS
        cutoff = 3000f + velocity * 3000f
    }
    private val vol = velocity * 0.5f

    init {
        osc.setFrequencyFromMidi(midi)
        env.noteOn()
    }

    fun getSample(sampleRate: Int): Float {
        val s = osc.getSample(sampleRate)
        val filtered = lpf.process(s)
        return filtered * env.getSample() * vol
    }

    fun release() { env.noteOff() }
    fun isActive() = env.isActive
    fun setMidi(midi: Int) { osc.setFrequencyFromMidi(midi) }
}
