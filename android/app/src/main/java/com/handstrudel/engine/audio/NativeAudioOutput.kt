package com.handstrudel.engine.audio

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import android.os.Process
import android.util.Log
import com.handstrudel.engine.AppAudioTap
import java.util.concurrent.CopyOnWriteArrayList
import kotlin.math.abs

/**
 * The native mix: one AudioTrack (USAGE_MEDIA / CONTENT_TYPE_MUSIC, no
 * exclusive focus so other apps' audio keeps playing, like iOS's mixable
 * playback session) fed by TinySoundFont on a dedicated audio thread.
 * Implements [AppAudioTap] so capture can record the native mix without a
 * MediaProjection prompt.
 */
internal class NativeAudioOutput(override val sampleRate: Int) : AppAudioTap {
    override val channelCount: Int = 2

    @Volatile var source: TinySoundFont? = null
    @Volatile private var running = false
    private var track: AudioTrack? = null
    private var thread: Thread? = null
    private val sinks = CopyOnWriteArrayList<(ShortArray, Int) -> Unit>()

    /** Peak |sample| of the native mix since the last [takePeak] (verification / meters). */
    @Volatile private var peak = 0f

    val audioSessionId: Int get() = track?.audioSessionId ?: 0

    fun takePeak(): Float = peak.also { peak = 0f }

    @Synchronized
    fun start(): Boolean {
        if (running) return true
        val minBytes = AudioTrack.getMinBufferSize(sampleRate, AudioFormat.CHANNEL_OUT_STEREO, AudioFormat.ENCODING_PCM_FLOAT)
        val t = try {
            AudioTrack.Builder()
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build(),
                )
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setSampleRate(sampleRate)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_STEREO)
                        .setEncoding(AudioFormat.ENCODING_PCM_FLOAT)
                        .build(),
                )
                .setBufferSizeInBytes(maxOf(minBytes, CHUNK * 2 * 4 * 2))
                .setTransferMode(AudioTrack.MODE_STREAM)
                .setPerformanceMode(AudioTrack.PERFORMANCE_MODE_LOW_LATENCY)
                .setSessionId(AudioManager.AUDIO_SESSION_ID_GENERATE)
                .build()
        } catch (e: Exception) {
            Log.e(TAG, "AudioTrack create failed", e)
            return false
        }
        if (t.state != AudioTrack.STATE_INITIALIZED) {
            t.release()
            return false
        }
        track = t
        running = true
        t.play()
        thread = Thread({ renderLoop(t) }, "HandStrudelAudio").apply { start() }
        return true
    }

    private fun renderLoop(t: AudioTrack) {
        Process.setThreadPriority(Process.THREAD_PRIORITY_URGENT_AUDIO)
        val buf = FloatArray(CHUNK * 2)
        var pcm = ShortArray(CHUNK * 2)
        while (running) {
            val sf = source
            if (sf != null) sf.render(buf, CHUNK) else buf.fill(0f)
            var p = 0f
            for (i in buf.indices) {
                val v = buf[i].coerceIn(-1f, 1f)
                buf[i] = v
                val a = abs(v)
                if (a > p) p = a
            }
            if (p > peak) peak = p
            if (sinks.isNotEmpty()) {
                if (pcm.size != buf.size) pcm = ShortArray(buf.size)
                for (i in buf.indices) pcm[i] = (buf[i] * 32767f).toInt().toShort()
                for (sink in sinks) runCatching { sink(pcm, CHUNK) }
            }
            val written = t.write(buf, 0, buf.size, AudioTrack.WRITE_BLOCKING)
            if (written < 0) {
                Log.w(TAG, "AudioTrack write error $written")
                Thread.sleep(5)
            }
        }
    }

    @Synchronized
    fun stop() {
        running = false
        thread?.join(500)
        thread = null
        track?.runCatching { stop(); release() }
        track = null
    }

    override fun open(sink: (pcm: ShortArray, frames: Int) -> Unit): AutoCloseable {
        sinks += sink
        return AutoCloseable { sinks -= sink }
    }

    companion object {
        private const val TAG = "NativeAudioOutput"
        const val CHUNK = 256
    }
}
