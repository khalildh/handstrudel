package com.handstrudel.capture

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioPlaybackCaptureConfiguration
import android.media.AudioRecord
import android.media.MediaRecorder
import android.media.projection.MediaProjection
import android.os.Process
import androidx.core.content.ContextCompat

/**
 * App-audio capture (the ReplayKit `.audioApp` equivalent): an [AudioRecord]
 * with [AudioPlaybackCaptureConfiguration] limited to this app's uid, which
 * picks up the native SoundFont/AudioTrack mix and the WebView's Strudel audio.
 * Optionally mixes the microphone in (iOS `recordPerformanceMicrophone`).
 *
 * Interleaved stereo 16-bit PCM at [SAMPLE_RATE]. Requires RECORD_AUDIO.
 */
class AppAudioCapture private constructor(
    private val app: AudioRecord,
    private val mic: AudioRecord?,
) : AutoCloseable {

    /** True once any non-zero app sample was read (R12: detect a silent capture). */
    @Volatile var heardSound = false
        private set

    private var micBuffer = ShortArray(0)

    fun start() {
        app.startRecording()
        mic?.startRecording()
    }

    /**
     * Blocks until [frames] stereo frames are read into [out] (size ≥ frames × 2).
     * Returns the frames read, or a negative AudioRecord error.
     */
    fun read(out: ShortArray, frames: Int): Int {
        val samples = app.read(out, 0, frames * CHANNELS, AudioRecord.READ_BLOCKING)
        if (samples <= 0) return samples
        val read = samples / CHANNELS
        if (!heardSound) {
            for (i in 0 until samples) if (out[i].toInt() != 0) { heardSound = true; break }
        }
        val mic = mic ?: return read
        if (micBuffer.size < read) micBuffer = ShortArray(read)
        val micRead = mic.read(micBuffer, 0, read, AudioRecord.READ_NON_BLOCKING)
        for (i in 0 until maxOf(0, micRead)) {
            val m = micBuffer[i].toInt()
            for (c in 0 until CHANNELS) {
                val index = i * CHANNELS + c
                out[index] = (out[index] + m).coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt()).toShort()
            }
        }
        return read
    }

    /**
     * Monotonic time (ns) of the first app-audio frame, from the capture's own timestamp, or
     * null when the device doesn't report one. Playback capture runs through a buffered
     * submix, so the time a read returns is a few hundred ms later than when the audio was
     * mixed; the video's timestamps are compositor times, so stamping audio by read time
     * leaves it late (≈0.3 s on a Nokia G10).
     */
    fun firstFrameNanos(): Long? {
        val ts = android.media.AudioTimestamp()
        if (app.getTimestamp(ts, android.media.AudioTimestamp.TIMEBASE_MONOTONIC) != AudioRecord.SUCCESS) return null
        if (ts.nanoTime <= 0L) return null
        return ts.nanoTime - ts.framePosition * 1_000_000_000L / SAMPLE_RATE
    }

    fun stop() {
        runCatching { app.stop() }
        runCatching { mic?.stop() }
    }

    override fun close() {
        stop()
        app.release()
        mic?.release()
    }

    companion object {
        const val SAMPLE_RATE = 44_100
        const val CHANNELS = 2

        fun hasRecordPermission(context: Context): Boolean =
            ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED

        /** Null when RECORD_AUDIO is missing or the device refuses playback capture. */
        @SuppressLint("MissingPermission")
        fun create(context: Context, projection: MediaProjection, includeMicrophone: Boolean): AppAudioCapture? {
            if (!hasRecordPermission(context)) return null
            val format = AudioFormat.Builder()
                .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                .setSampleRate(SAMPLE_RATE)
                .setChannelMask(AudioFormat.CHANNEL_IN_STEREO)
                .build()
            val minBuffer = AudioRecord.getMinBufferSize(SAMPLE_RATE, AudioFormat.CHANNEL_IN_STEREO, AudioFormat.ENCODING_PCM_16BIT)
            val bufferBytes = maxOf(minBuffer, SAMPLE_RATE * CHANNELS * 2 / 5) // ≥ 200 ms
            val config = AudioPlaybackCaptureConfiguration.Builder(projection)
                .addMatchingUsage(AudioAttributes.USAGE_MEDIA)
                .addMatchingUsage(AudioAttributes.USAGE_GAME)
                .addMatchingUsage(AudioAttributes.USAGE_UNKNOWN)
                .addMatchingUid(Process.myUid())
                .build()
            val app = try {
                AudioRecord.Builder()
                    .setAudioFormat(format)
                    .setBufferSizeInBytes(bufferBytes)
                    .setAudioPlaybackCaptureConfig(config)
                    .build()
            } catch (e: Exception) {
                return null
            }
            if (app.state != AudioRecord.STATE_INITIALIZED) {
                app.release()
                return null
            }
            val mic = if (includeMicrophone) runCatching {
                AudioRecord.Builder()
                    .setAudioSource(MediaRecorder.AudioSource.MIC)
                    .setAudioFormat(
                        AudioFormat.Builder().setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                            .setSampleRate(SAMPLE_RATE).setChannelMask(AudioFormat.CHANNEL_IN_MONO).build(),
                    )
                    .setBufferSizeInBytes(maxOf(AudioRecord.getMinBufferSize(SAMPLE_RATE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT), SAMPLE_RATE))
                    .build()
                    .takeIf { it.state == AudioRecord.STATE_INITIALIZED }
            }.getOrNull() else null
            return AppAudioCapture(app, mic)
        }
    }
}
