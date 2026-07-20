package com.handstrudel.engine.synth

import android.content.Context
import android.util.Log
import java.util.concurrent.atomic.AtomicLong

/**
 * Kotlin facade over the TinySoundFont JNI wrapper. Loads a SoundFont 2 file
 * from app assets once and serves [noteOn] / [noteOff] / [renderInto] calls
 * to the rest of the engine.
 *
 * Notes are addressed by a string `voiceId` (e.g. `"cmm-pad-0"`,
 * `"splittouch-3-c1"`) rather than the raw (preset, key) pair so callers can
 * release exactly the voice they started even if multiple voices share the
 * same MIDI note. Internally the engine remembers each voice's
 * `(preset, key)` so it can route the release back to TSF.
 *
 * Rendering integrates with the existing [SynthEngine] audio thread: that
 * thread calls [renderInto] each chunk and adds the resulting samples to its
 * own buffer.
 */
class SoundFontEngine private constructor(
    private val handle: Long,
    val sampleRate: Int,
) {

    private val voices = mutableMapOf<String, ActiveVoice>()
    private var defaultPreset: Int = 0  // 0 = Acoustic Grand Piano in GM
    @Volatile private var closed = false

    private data class ActiveVoice(val preset: Int, val midi: Int)

    fun setDefaultPreset(preset: Int) {
        defaultPreset = preset
    }

    fun noteOn(voiceId: String, midi: Int, velocity: Float, preset: Int = defaultPreset) {
        if (closed) return
        // If this voice is already playing, release the previous note first.
        synchronized(voices) {
            voices[voiceId]?.let { nativeNoteOff(handle, it.preset, it.midi) }
            voices[voiceId] = ActiveVoice(preset, midi)
        }
        nativeNoteOn(handle, preset, midi, velocity.coerceIn(0f, 1f))
    }

    fun noteOff(voiceId: String) {
        if (closed) return
        val active = synchronized(voices) { voices.remove(voiceId) } ?: return
        nativeNoteOff(handle, active.preset, active.midi)
    }

    /** Slide a held voice to a new MIDI note (release old, retrigger new). */
    fun noteSlide(voiceId: String, midi: Int, velocity: Float = 0.7f) {
        val prev = synchronized(voices) { voices[voiceId] } ?: return
        noteOn(voiceId, midi, velocity, prev.preset)
    }

    fun allNotesOff() {
        if (closed) return
        synchronized(voices) { voices.clear() }
        nativeAllNotesOff(handle)
    }

    /**
     * Render [sampleCount] stereo frames into [out] (length ≥ sampleCount*2,
     * interleaved L/R shorts). If [mix] is true, samples are *added* to
     * whatever's already in the buffer; otherwise the buffer is overwritten.
     */
    fun renderInto(out: ShortArray, sampleCount: Int, mix: Boolean) {
        if (closed) return
        nativeRender(handle, out, sampleCount, mix)
    }

    fun close() {
        if (closed) return
        closed = true
        nativeClose(handle)
    }

    companion object {
        private const val TAG = "SoundFontEngine"
        private val ID = AtomicLong()

        init {
            System.loadLibrary("handstrudel_tsf")
        }

        /**
         * Load a SoundFont from assets. Returns `null` if the file can't be
         * read or TSF rejects it.
         */
        fun fromAsset(context: Context, assetPath: String, sampleRate: Int, gainDb: Float = -6f): SoundFontEngine? {
            val bytes = try {
                context.assets.open(assetPath).use { it.readBytes() }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to read SF2 asset $assetPath", e)
                return null
            }
            val handle = nativeLoad(bytes, sampleRate, gainDb)
            if (handle == 0L) {
                Log.e(TAG, "TinySoundFont rejected $assetPath (handle=0)")
                return null
            }
            Log.i(TAG, "Loaded $assetPath (handle=$handle, ${bytes.size} bytes, $sampleRate Hz)")
            return SoundFontEngine(handle, sampleRate)
        }

        @JvmStatic external fun nativeLoad(sf2Bytes: ByteArray, sampleRate: Int, gainDb: Float): Long
        @JvmStatic external fun nativeClose(handle: Long)
        @JvmStatic external fun nativeNoteOn(handle: Long, preset: Int, midi: Int, velocity: Float)
        @JvmStatic external fun nativeNoteOff(handle: Long, preset: Int, midi: Int)
        @JvmStatic external fun nativeAllNotesOff(handle: Long)
        @JvmStatic external fun nativeRender(handle: Long, out: ShortArray, sampleCount: Int, mix: Boolean)
    }
}
