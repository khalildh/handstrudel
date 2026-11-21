package com.handstrudel.capture

import android.content.Context
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaCodecList
import android.media.MediaFormat
import android.media.MediaMuxer
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.WindowManager
import java.io.File
import java.nio.ByteBuffer
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import kotlin.math.roundToInt

/**
 * One stage take: the projection's virtual display feeds an H.264 surface
 * encoder, [AppAudioCapture] feeds an AAC encoder, both muxed into [output]
 * (MP4). The ReplayKit `startRecording`/`stopRecording(withOutput:)` equivalent.
 */
class ScreenRecorder(
    private val context: Context,
    private val output: File,
    private val audio: AppAudioCapture?,
    /** Called once, from a worker thread, if encoding fails mid-take. */
    private val onFailure: (Exception) -> Unit,
) {
    data class Size(val width: Int, val height: Int, val densityDpi: Int)

    private val main = Handler(Looper.getMainLooper())
    private lateinit var videoCodec: MediaCodec
    private var audioCodec: MediaCodec? = null
    private lateinit var muxer: MediaMuxer
    private val lock = Object()
    private var videoTrack = -1
    private var audioTrack = -1
    private var muxerStarted = false
    private var muxedVideoSamples = 0
    private val pending = ArrayList<Triple<Boolean, ByteArray, MediaCodec.BufferInfo>>()
    @Volatile private var stopping = false
    @Volatile private var failed: Exception? = null
    private var videoThread: Thread? = null
    private var audioThread: Thread? = null
    private val finished = CountDownLatch(2)
    private var baseUs = 0L

    /** Starts encoding. Main thread (it binds the virtual display). */
    fun start() {
        val size = captureSize(context)
        val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, size.width, size.height).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
            setInteger(MediaFormat.KEY_BIT_RATE, (size.width * size.height * 30 * 0.15).roundToInt().coerceAtMost(10_000_000))
            setInteger(MediaFormat.KEY_FRAME_RATE, 30)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
            // Keep frames flowing when the stage is still, so the take has its full length.
            setLong(MediaFormat.KEY_REPEAT_PREVIOUS_FRAME_AFTER, 1_000_000L / 30)
        }
        videoCodec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
        videoCodec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        val surface = videoCodec.createInputSurface()
        muxer = MediaMuxer(output.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        if (audio != null) {
            val audioFormat = MediaFormat.createAudioFormat(MediaFormat.MIMETYPE_AUDIO_AAC, AppAudioCapture.SAMPLE_RATE, AppAudioCapture.CHANNELS).apply {
                setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
                setInteger(MediaFormat.KEY_BIT_RATE, 128_000)
                setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 16_384)
            }
            audioCodec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC).apply {
                configure(audioFormat, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            }
        }
        baseUs = System.nanoTime() / 1000
        videoCodec.start()
        audioCodec?.start()
        CaptureProjection.bindSurface(surface, size.width, size.height, size.densityDpi)
        videoThread = Thread({ drainVideo() }, "hs-video-encoder").apply { start() }
        if (audioCodec != null) {
            audio!!.start()
            audioThread = Thread({ pumpAudio() }, "hs-audio-encoder").apply { start() }
        } else {
            finished.countDown()
        }
    }

    /** Whether the take heard any app sound (false when audio capture was unavailable). */
    val heardSound: Boolean get() = audio?.heardSound == true
    val hasAudio: Boolean get() = audio != null

    /**
     * Stops and finalizes the file. Blocking: call off the main thread. Throws if
     * nothing usable was written (the caller then discards the draft).
     */
    fun stop() {
        stopping = true
        main.post { runCatching { CaptureProjection.bindSurface(null, 0, 0, 0) } }
        runCatching { videoCodec.signalEndOfInputStream() }
        finished.await(5, TimeUnit.SECONDS)
        audio?.close()
        runCatching { videoCodec.stop() }
        videoCodec.release()
        audioCodec?.let { runCatching { it.stop() }; it.release() }
        synchronized(lock) {
            try {
                if (muxerStarted) muxer.stop()
            } catch (e: Exception) {
                if (failed == null) failed = e
            } finally {
                runCatching { muxer.release() }
            }
            if (!muxerStarted || muxedVideoSamples == 0) throw IllegalStateException("The recording has no video.")
        }
        failed?.let { if (output.length() == 0L) throw it }
    }

    private fun drainVideo() {
        val info = MediaCodec.BufferInfo()
        var stopSince = 0L
        try {
            while (true) {
                val index = videoCodec.dequeueOutputBuffer(info, 10_000)
                when {
                    index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> synchronized(lock) {
                        videoTrack = muxer.addTrack(videoCodec.outputFormat)
                        maybeStartMuxer()
                    }
                    index >= 0 -> {
                        val buffer = videoCodec.getOutputBuffer(index)!!
                        if (info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) info.size = 0
                        if (info.size > 0) write(true, buffer, info)
                        videoCodec.releaseOutputBuffer(index, false)
                        if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) break
                    }
                    index == MediaCodec.INFO_TRY_AGAIN_LATER && stopping -> {
                        if (stopSince == 0L) stopSince = System.nanoTime()
                        else if (System.nanoTime() - stopSince > 3_000_000_000L) break
                    }
                }
            }
        } catch (e: Exception) {
            fail(e)
        } finally {
            finished.countDown()
        }
    }

    private fun pumpAudio() {
        val codec = audioCodec!!
        val capture = audio!!
        val frames = 1024
        val pcm = ShortArray(frames * AppAudioCapture.CHANNELS)
        val info = MediaCodec.BufferInfo()
        var written = 0L
        var startUs = -1L
        var sawEos = false
        var queuedEos = false
        try {
            while (!sawEos) {
                if (!queuedEos) {
                    val input = codec.dequeueInputBuffer(10_000)
                    if (input >= 0) {
                        val buffer = codec.getInputBuffer(input)!!
                        if (stopping) {
                            codec.queueInputBuffer(input, 0, 0, presentationUs(startUs, written), MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            queuedEos = true
                        } else {
                            val read = capture.read(pcm, frames)
                            if (read < 0) throw IllegalStateException("Audio capture failed ($read).")
                            if (startUs < 0) startUs = System.nanoTime() / 1000 - read * 1_000_000L / AppAudioCapture.SAMPLE_RATE
                            buffer.clear()
                            buffer.asShortBuffer().put(pcm, 0, read * AppAudioCapture.CHANNELS)
                            codec.queueInputBuffer(input, 0, read * AppAudioCapture.CHANNELS * 2, presentationUs(startUs, written), 0)
                            written += read
                        }
                    }
                }
                while (true) {
                    val index = codec.dequeueOutputBuffer(info, 0)
                    if (index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                        synchronized(lock) {
                            audioTrack = muxer.addTrack(codec.outputFormat)
                            maybeStartMuxer()
                        }
                    } else if (index >= 0) {
                        val buffer = codec.getOutputBuffer(index)!!
                        if (info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) info.size = 0
                        if (info.size > 0) write(false, buffer, info)
                        codec.releaseOutputBuffer(index, false)
                        if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) { sawEos = true; break }
                    } else break
                }
            }
        } catch (e: Exception) {
            fail(e)
        } finally {
            finished.countDown()
        }
    }

    private fun presentationUs(startUs: Long, frames: Long): Long =
        maxOf(0L, startUs) + frames * 1_000_000L / AppAudioCapture.SAMPLE_RATE

    private fun write(isVideo: Boolean, buffer: ByteBuffer, info: MediaCodec.BufferInfo) {
        val sample = MediaCodec.BufferInfo().apply {
            set(0, info.size, info.presentationTimeUs - baseUs, info.flags)
        }
        if (sample.presentationTimeUs < 0) return
        buffer.position(info.offset)
        buffer.limit(info.offset + info.size)
        synchronized(lock) {
            if (!muxerStarted) {
                val copy = ByteArray(info.size)
                buffer.get(copy)
                pending += Triple(isVideo, copy, sample)
                return
            }
            muxer.writeSampleData(if (isVideo) videoTrack else audioTrack, buffer, sample)
            if (isVideo) muxedVideoSamples++
        }
    }

    /** Caller holds [lock]. */
    private fun maybeStartMuxer() {
        if (muxerStarted || videoTrack < 0 || (audioCodec != null && audioTrack < 0)) return
        muxer.start()
        muxerStarted = true
        for ((isVideo, bytes, info) in pending) {
            muxer.writeSampleData(if (isVideo) videoTrack else audioTrack, ByteBuffer.wrap(bytes), info)
            if (isVideo) muxedVideoSamples++
        }
        pending.clear()
    }

    private fun fail(e: Exception) {
        Log.w(TAG, "Encoding failed", e)
        if (failed == null && !stopping) {
            failed = e
            main.post { onFailure(e) }
        }
    }

    companion object {
        private const val TAG = "ScreenRecorder"
        private const val MAX_WIDTH = 1080

        /** The portrait screen scaled to ≤1080 wide, 16-aligned and supported by the AVC encoder. */
        fun captureSize(context: Context): Size {
            val bounds = context.getSystemService(WindowManager::class.java).maximumWindowMetrics.bounds
            val dpi = context.resources.displayMetrics.densityDpi
            var width = minOf(bounds.width(), bounds.height())
            var height = maxOf(bounds.width(), bounds.height())
            val codecs = MediaCodecList(MediaCodecList.REGULAR_CODECS).codecInfos
                .filter { it.isEncoder && it.supportedTypes.any { t -> t.equals(MediaFormat.MIMETYPE_VIDEO_AVC, true) } }
            var scale = minOf(1.0, MAX_WIDTH.toDouble() / width)
            repeat(8) {
                val w = (width * scale).toInt() / 16 * 16
                val h = (height * scale).toInt() / 16 * 16
                val ok = codecs.any {
                    runCatching { it.getCapabilitiesForType(MediaFormat.MIMETYPE_VIDEO_AVC).videoCapabilities.isSizeSupported(w, h) }
                        .getOrDefault(false)
                }
                if (ok || codecs.isEmpty()) return Size(w, h, (dpi * scale).roundToInt().coerceAtLeast(120))
                scale *= 0.8
            }
            width = 720; height = 1280
            return Size(width, height, dpi)
        }
    }
}
