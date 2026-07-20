package com.handstrudel.engine.synth

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.os.Process
import android.util.Log
import kotlin.math.PI
import kotlin.math.sin

class SynthEngine(private val sampleRate: Int = 44100) {
    private var audioTrack: AudioTrack? = null
    private var audioThread: Thread? = null
    @Volatile private var running = false

    // Simple melodic voice — just oscillator + filter
    private var phase = 0.0
    private val lpf = BiquadFilter(sampleRate).apply { type = FilterType.LOW_PASS; cutoff = 3000f }

    // Grid mode voices
    private val noteVoices = mutableMapOf<String, NoteVoice>()

    /// Optional SoundFont engine. When set, its samples are mixed into the
    /// output buffer for every chunk — used for Split chord+melody so the
    /// pad + melody voices come out of a real instrument instead of a raw
    /// oscillator. Caller is responsible for invoking [SoundFontEngine.noteOn]
    /// etc. before mixing; the audio thread just drains samples.
    @Volatile var soundFont: SoundFontEngine? = null
    /// Scratch buffer for [SoundFontEngine.renderInto] each chunk. Sized for
    /// 256 stereo frames (matches the audio thread's chunk).
    private val sfBuffer = ShortArray(256 * 2)

    // Drums
    val drumSynth = DrumSynth(sampleRate)

    // Parameters (volatile for cross-thread)
    @Volatile var melodicMidi: Int = 60
    @Volatile var melodicWaveform: String = "sawtooth"
    @Volatile var gain: Float = 0.3f
    @Volatile var lpfCutoff: Float = 3000f
    @Volatile var reverbMix: Float = 0.0f
    @Volatile var delayTime: Float = 0.0f
    @Volatile var panValue: Float = 0.5f
    @Volatile var crushBits: Float = 16f
    @Volatile var shapeAmount: Float = 0f
    @Volatile var hpfCutoff: Float = 20f
    @Volatile var attackTime: Float = 0.01f
    @Volatile var releaseTime: Float = 0.1f
    @Volatile var bpm: Float = 120f
    @Volatile var structPattern: String = "x ~ x ~ x ~ x ~"
    @Volatile var melodicActive: Boolean = true // set to true when hands detected

    // Beat
    @Volatile var currentBeat: Int = 0
    var onBeat: ((Int) -> Unit)? = null
    private var sampleCount: Long = 0

    fun start() {
        if (running) return
        running = true

        val bufferSize = AudioTrack.getMinBufferSize(
            sampleRate, AudioFormat.CHANNEL_OUT_STEREO, AudioFormat.ENCODING_PCM_16BIT
        )

        audioTrack = AudioTrack.Builder()
            .setAudioAttributes(AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                .build())
            .setAudioFormat(AudioFormat.Builder()
                .setSampleRate(sampleRate)
                .setChannelMask(AudioFormat.CHANNEL_OUT_STEREO)
                .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                .build())
            .setBufferSizeInBytes(bufferSize * 2)
            .setTransferMode(AudioTrack.MODE_STREAM)
            .build()

        audioTrack?.play()

        audioThread = Thread({
            Process.setThreadPriority(Process.THREAD_PRIORITY_URGENT_AUDIO)
            val chunk = 256
            val buffer = ShortArray(chunk * 2)

            while (running) {
                for (i in 0 until chunk) {
                    var sample = 0f
                    sampleCount++

                    // Beat tracking
                    val samplesPerBeat = (sampleRate * 60.0 / bpm).toLong()
                    val beat = ((sampleCount / samplesPerBeat) % 4).toInt()
                    if (beat != currentBeat) {
                        currentBeat = beat
                        onBeat?.invoke(beat)
                    }

                    // Melodic: continuous tone controlled by hands
                    if (melodicActive) {
                        val freq = 440.0 * Math.pow(2.0, (melodicMidi - 69).toDouble() / 12.0)
                        val phaseInc = freq / sampleRate

                        val osc = when (melodicWaveform) {
                            "sine" -> sin(2.0 * PI * phase).toFloat()
                            "square" -> if ((phase % 1.0) < 0.5) 0.8f else -0.8f
                            "triangle" -> (4.0 * Math.abs((phase % 1.0) - 0.5) - 1.0).toFloat()
                            else -> (2.0 * (phase % 1.0) - 1.0).toFloat() // sawtooth
                        }
                        phase += phaseInc
                        if (phase > 100.0) phase -= 100.0

                        sample += osc * 0.25f
                    }

                    // Grid voices
                    synchronized(noteVoices) {
                        val iter = noteVoices.entries.iterator()
                        while (iter.hasNext()) {
                            val voice = iter.next().value
                            sample += voice.getSample(sampleRate)
                            if (!voice.isActive()) iter.remove()
                        }
                    }

                    // Drums
                    sample += drumSynth.getSample() * 0.5f

                    // Simple filter
                    lpf.cutoff = lpfCutoff
                    sample = lpf.process(sample)

                    // Master gain + soft clip
                    sample *= gain
                    sample = sample.coerceIn(-0.95f, 0.95f)

                    // Stereo pan
                    val panAngle = panValue * PI.toFloat() / 2f
                    val left = sample * kotlin.math.cos(panAngle)
                    val right = sample * kotlin.math.sin(panAngle)

                    buffer[i * 2] = (left * 32000).toInt().coerceIn(-32768, 32767).toShort()
                    buffer[i * 2 + 1] = (right * 32000).toInt().coerceIn(-32768, 32767).toShort()
                }

                // SoundFont mix-in. Render TSF into its own buffer, then add
                // to ours sample-by-sample (saturate to avoid clipping).
                soundFont?.let { sf ->
                    sf.renderInto(sfBuffer, chunk, mix = false)
                    var i = 0
                    while (i < buffer.size) {
                        val combined = buffer[i].toInt() + sfBuffer[i].toInt()
                        buffer[i] = combined.coerceIn(-32768, 32767).toShort()
                        i++
                    }
                }

                audioTrack?.write(buffer, 0, buffer.size)
            }
        }, "SynthAudio").apply { priority = Thread.MAX_PRIORITY }
        audioThread?.start()
        Log.d("SynthEngine", "Started")
    }

    fun stop() {
        running = false
        audioThread?.join(1000)
        audioTrack?.stop()
        audioTrack?.release()
        audioTrack = null
    }

    fun noteOn(hand: String, midi: Int, waveform: String, velocity: Float) {
        val voice = NoteVoice(sampleRate, midi, waveform, velocity)
        synchronized(noteVoices) {
            noteVoices[hand]?.release()
            noteVoices[hand] = voice
        }
    }

    fun noteOff(hand: String) {
        synchronized(noteVoices) { noteVoices[hand]?.release() }
    }

    fun noteSlide(hand: String, midi: Int) {
        synchronized(noteVoices) { noteVoices[hand]?.setMidi(midi) }
    }

    fun playHit(type: String) {
        drumSynth.triggerHit(type)
    }

    fun updateStructPattern(pattern: String) {
        structPattern = pattern
    }
}

private class NoteVoice(
    private val sr: Int,
    midi: Int,
    waveform: String,
    velocity: Float
) {
    private var phase = 0.0
    private var freq = 440.0 * Math.pow(2.0, (midi - 69).toDouble() / 12.0)
    private val wf = waveform
    private val vol = velocity.coerceIn(0.1f, 1f) * 0.3f
    private val filter = BiquadFilter(sr).apply {
        type = FilterType.LOW_PASS
        cutoff = 2000f + velocity * 4000f
    }
    private var envelope = 0f
    private var releasing = false
    private var alive = true

    fun getSample(sampleRate: Int): Float {
        if (!alive) return 0f

        val osc = when (wf) {
            "sine" -> sin(2.0 * PI * phase).toFloat()
            "square" -> if ((phase % 1.0) < 0.5) 0.8f else -0.8f
            "triangle" -> (4.0 * Math.abs((phase % 1.0) - 0.5) - 1.0).toFloat()
            else -> (2.0 * (phase % 1.0) - 1.0).toFloat()
        }
        phase += freq / sampleRate
        if (phase > 100.0) phase -= 100.0

        // Envelope
        if (!releasing) {
            envelope = (envelope + 0.002f).coerceAtMost(1f) // ~5ms attack
        } else {
            envelope *= 0.9995f // smooth release
            if (envelope < 0.001f) { alive = false; return 0f }
        }

        return filter.process(osc) * vol * envelope
    }

    fun release() { releasing = true }
    fun isActive() = alive
    fun setMidi(midi: Int) { freq = 440.0 * Math.pow(2.0, (midi - 69).toDouble() / 12.0) }
}
