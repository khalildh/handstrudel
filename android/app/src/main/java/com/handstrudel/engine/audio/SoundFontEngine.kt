package com.handstrudel.engine.audio

import android.content.Context
import android.media.AudioManager
import android.os.Handler
import android.os.Looper
import android.util.Log

/**
 * Port of iOS `Engine/SoundFontEngine.swift` on TinySoundFont + the bundled
 * GeneralUser-GS.sf2. Same voice → channel routing, velocity mapping,
 * one-shot accents with token-guarded releases, and hard stops. Main thread.
 */
class SoundFontEngine(private val context: Context) {
    private val main = Handler(Looper.getMainLooper())
    private val loadLock = Object()
    private var tsf: TinySoundFont? = null
    private var loadFailed = false
    internal val output: NativeAudioOutput = NativeAudioOutput(nativeSampleRate(context))

    var onNoteStarted: (() -> Unit)? = null

    var isAvailable: Boolean = false
        private set
    var currentProgram: Int = 0
        private set

    private val voiceChannels = mutableMapOf<String, Int>()
    private val activeNotes = linkedMapOf<String, SamplerRouting.ActiveNote>()
    private val voiceVelocity = mutableMapOf<String, Int>()
    private val accentReleases = SamplerAccentReleases()

    /** Loads the SoundFont off the main thread so the first start is instant. */
    fun preload() {
        Thread({ ensureLoaded() }, "SoundFontLoad").start()
    }

    private fun ensureLoaded(): TinySoundFont? = synchronized(loadLock) {
        tsf?.let { return it }
        if (loadFailed) return null
        val bytes = try {
            context.assets.open(SF2_ASSET).use { it.readBytes() }
        } catch (e: Exception) {
            Log.e(TAG, "no .sf2 in assets: SoundFont routing will be silent", e)
            loadFailed = true
            return null
        }
        // iOS: AVAudioUnitSampler at unity gain into the main mixer, SF2 velocity curve
        // (amplitude = velocity², built into tsf.h via TSF_SF2_VELOCITY_CURVE). Same levels here.
        val loaded = TinySoundFont.load(bytes, output.sampleRate, IOS_SAMPLER_GAIN_DB)
        if (loaded == null) loadFailed = true
        tsf = loaded
        loaded
    }

    /** iOS `startIfNeeded(program:)`: brings up the audio graph; idempotent. */
    fun startIfNeeded(program: Int): Boolean {
        if (isAvailable) {
            if (!output.start()) return false
            return true
        }
        val sf = ensureLoaded() ?: return false
        output.source = sf
        if (!output.start()) return false
        if (!loadProgram(sf, program, force = true)) return false
        isAvailable = true
        Log.i(TAG, "ready program=$program rate=${output.sampleRate}")
        return true
    }

    fun setInstrument(program: Int) {
        if (program == currentProgram && isAvailable) return
        allNotesOff()
        tsf?.let { loadProgram(it, program, force = false) }
    }

    private fun loadProgram(sf: TinySoundFont, program: Int, force: Boolean): Boolean {
        if (sf.setProgram(program)) {
            currentProgram = program
            return true
        }
        Log.w(TAG, "program $program missing; ${if (force) "falling back to 0" else "kept $currentProgram"}")
        return if (program != 0 && force) loadProgram(sf, 0, force = false) else false
    }

    fun noteOn(voice: String, midi: Int, velocity: Double) {
        val sf = tsf.takeIf { isAvailable } ?: return
        val note = SamplerRouting.clampMidi(midi)
        val vel = SamplerRouting.clampVelocity(velocity)
        activeNotes.remove(voice)?.let { sf.noteOff(it.channel, it.midi) }
        val channel = channelFor(voice, note) ?: return
        sf.noteOn(channel, note, vel / 127f)
        activeNotes[voice] = SamplerRouting.ActiveNote(note, channel)
        voiceVelocity[voice] = vel
        onNoteStarted?.invoke()
    }

    fun noteOff(voice: String) {
        val sf = tsf.takeIf { isAvailable } ?: return
        val active = activeNotes.remove(voice) ?: return
        sf.noteOff(active.channel, active.midi)
    }

    /** Release and forget the voice's channel/velocity (touch and preview voices). */
    fun releaseTemporaryVoice(voice: String) {
        noteOff(voice)
        voiceChannels.remove(voice)
        voiceVelocity.remove(voice)
    }

    /** Stop now, cutting the release tail (CC 120) when no other voice shares the channel. */
    fun hardStop(voice: String) {
        val sf = tsf.takeIf { isAvailable } ?: return
        val active = activeNotes.remove(voice) ?: return
        sf.noteOff(active.channel, active.midi)
        if (activeNotes.values.none { it.channel == active.channel }) sf.soundsOff(active.channel)
    }

    /** Move a held voice to a new pitch at its original velocity. */
    fun slide(voice: String, midi: Int) {
        val sf = tsf.takeIf { isAvailable } ?: return
        val note = SamplerRouting.clampMidi(midi)
        activeNotes[voice]?.let { if (it.midi == note) return }
        activeNotes.remove(voice)?.let { sf.noteOff(it.channel, it.midi) }
        val channel = channelFor(voice, note) ?: return
        val vel = voiceVelocity[voice] ?: SamplerRouting.clampVelocity(0.6)
        sf.noteOn(channel, note, vel / 127f)
        activeNotes[voice] = SamplerRouting.ActiveNote(note, channel)
    }

    /** Fire-and-forget accent on the one-shot channel, released after [duration] s. */
    fun oneShot(midi: Int, velocity: Double, duration: Double) {
        val sf = tsf.takeIf { isAvailable } ?: return
        val note = SamplerRouting.clampMidi(midi)
        val vel = SamplerRouting.clampVelocity(velocity)
        val strike = accentReleases.strike(note)
        if (strike.replacesEarlierStrike) sf.noteOff(SamplerRouting.ONE_SHOT_CHANNEL, note)
        sf.noteOn(SamplerRouting.ONE_SHOT_CHANNEL, note, vel / 127f)
        val delay = if (duration.isFinite()) duration.coerceIn(0.05, 60.0) else 0.05
        main.postDelayed({
            if (accentReleases.shouldRelease(note, strike.token)) tsf?.noteOff(SamplerRouting.ONE_SHOT_CHANNEL, note)
        }, (delay * 1000).toLong())
    }

    fun allNotesOff() {
        accentReleases.clear()
        val sf = tsf.takeIf { isAvailable } ?: return
        for ((_, a) in activeNotes) sf.noteOff(a.channel, a.midi)
        activeNotes.clear()
        for (ch in 0..15) sf.notesOff(ch)
    }

    /** Native voices currently sounding (verification and debug). */
    val activeVoiceCount: Int get() = tsf?.activeVoices() ?: 0

    /** Stop the audio thread (app teardown). */
    fun shutdown() {
        output.stop()
    }

    private fun channelFor(voice: String, note: Int): Int? {
        val ch = SamplerRouting.sustainedChannel(note, voiceChannels[voice], activeNotes.values.toList()) ?: return null
        voiceChannels[voice] = ch
        return ch
    }

    companion object {
        private const val TAG = "SoundFontEngine"
        const val SF2_ASSET = "soundfonts/GeneralUser-GS.sf2"
        /** AVAudioUnitSampler's default master gain. */
        const val IOS_SAMPLER_GAIN_DB = 0f

        private fun nativeSampleRate(context: Context): Int {
            val am = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
            return am?.getProperty(AudioManager.PROPERTY_OUTPUT_SAMPLE_RATE)?.toIntOrNull()?.takeIf { it in 8000..192000 } ?: 48000
        }
    }
}
