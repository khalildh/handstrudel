package com.handstrudel.engine.audio

/**
 * Thin JNI facade over TinySoundFont (`src/main/cpp/tsf_jni.cpp`). All calls
 * are thread-safe (the native side holds a mutex); [render] runs on the audio
 * thread, everything else on the main thread.
 */
internal class TinySoundFont private constructor(private val handle: Long) {
    @Volatile private var closed = false

    fun setProgram(program: Int): Boolean = !closed && nativeSetProgram(handle, program)
    fun noteOn(channel: Int, key: Int, velocity: Float) { if (!closed) nativeChannelNoteOn(handle, channel, key, velocity) }
    fun noteOff(channel: Int, key: Int) { if (!closed) nativeChannelNoteOff(handle, channel, key) }
    /** MIDI CC 120 equivalent: cut the channel's voices immediately. */
    fun soundsOff(channel: Int) { if (!closed) nativeChannelSoundsOff(handle, channel) }
    /** MIDI CC 123 equivalent: release the channel's notes with their envelopes. */
    fun notesOff(channel: Int) { if (!closed) nativeChannelNotesOff(handle, channel) }
    fun activeVoices(): Int = if (closed) 0 else nativeActiveVoices(handle)

    /** Renders [frames] interleaved stereo float frames into [out] (overwrites). */
    fun render(out: FloatArray, frames: Int) { if (!closed) nativeRender(handle, out, frames) }

    fun close() {
        if (closed) return
        closed = true
        nativeClose(handle)
    }

    companion object {
        init { System.loadLibrary("handstrudel_tsf") }

        fun load(sf2: ByteArray, sampleRate: Int, gainDb: Float): TinySoundFont? =
            nativeLoad(sf2, sampleRate, gainDb).takeIf { it != 0L }?.let(::TinySoundFont)

        @JvmStatic private external fun nativeLoad(sf2Bytes: ByteArray, sampleRate: Int, gainDb: Float): Long
        @JvmStatic private external fun nativeClose(handle: Long)
        @JvmStatic private external fun nativeSetProgram(handle: Long, program: Int): Boolean
        @JvmStatic private external fun nativeChannelNoteOn(handle: Long, channel: Int, key: Int, velocity: Float)
        @JvmStatic private external fun nativeChannelNoteOff(handle: Long, channel: Int, key: Int)
        @JvmStatic private external fun nativeChannelSoundsOff(handle: Long, channel: Int)
        @JvmStatic private external fun nativeChannelNotesOff(handle: Long, channel: Int)
        @JvmStatic private external fun nativeActiveVoices(handle: Long): Int
        @JvmStatic private external fun nativeRender(handle: Long, out: FloatArray, frames: Int)
    }
}
